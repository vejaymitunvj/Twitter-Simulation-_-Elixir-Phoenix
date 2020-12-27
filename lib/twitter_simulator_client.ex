################################# START OF APP ######################################
#################################### START OF TwitterSimulator ######################################
########################################################################################
#####                                                                                 ##
##### Description: The application module which accepts the commandline arguments     ##
#####              and starts the twitter engine                                      ##
#####                                                                                 ##
#####                                                                                 ##
#####                                                                                 ##
#####                                                                                 ##
########################################################################################
#
defmodule TwitterSimulator.Client do
  @moduledoc """
    Documentation for TwitterSimulator. This is the main function via which we are gonna run the simulator.
    Two form of input arguments will be provided, one with 0 arguments to start the server & another with 2 arguments to run
    the client simulation
  """

  @doc """
  ## Examples
  """
  use GenServer
  require Logger

  def start_link(client_id, total_clients) do
    # We don't want out main program to crash when the individual clients quit.
    # Hence, let's not link the processes.
    GenServer.start(__MODULE__, {client_id, total_clients}, name: :"client_#{client_id}")
  end

  def start_node(ip_addr, my_id) do
    my_node = String.to_atom("client_#{my_id}@" <> ip_addr)
    Node.start(my_node)
    Node.set_cookie(my_node, :hakuna)
    server_node = String.to_atom("server@" <> ip_addr)
    :global.register_name(:"client_#{my_id}", self())
    IO.puts("Trying to connect to #{server_node}")
    Node.connect(server_node)
    # Wait for connection to complete
    wait_connection(server_node, my_id, 0)
  end

  def wait_connection(server_node, my_id, count) do
    if Node.ping(server_node) == "ping" do
      if div(count, 10) > 1 do
        Process.sleep(100 * div(count, 10))
      else
        Process.sleep(100)
      end 
      Logger.info("Client #{my_id} is waiting for connection...")
      wait_connection(server_node, my_id, count + 1)
    end
  end

  def find_ip_start_node(ip_list, my_id) do
    [head | tail] = ip_list

    unless Node.alive?() do
      try do
        {possible_ip, _, _} = head
        ip = to_string(:inet_parse.ntoa(possible_ip))

        if ip == "127.0.0.1" do
          if length(ip_list) > 1 do
            find_ip_start_node(tail, my_id)
          else
            Logger.warn("Unable to start the client node in a distributed mode")
          end
        else
          start_node(ip, my_id)
        end
      rescue
        _e ->
          if length(ip_list) > 1 do
            find_ip_start_node(tail, my_id)
          else
            Logger.warn("Unable to start the client node in a distributed mode")
          end
      end
    end
  end

  @impl true
  def init({client_id, total_clients}) do
    live_status = false
    simulation_mode = false
    follow_list = []
    :ets.new(:"client#{client_id}_follow_list", [:set, :public, :named_table])
    :ets.insert(:"client#{client_id}_follow_list", {"follow_list", follow_list})
    state = {client_id, live_status, simulation_mode, total_clients, follow_list}
    start_client({client_id})
    register_client(client_id)
    login_client(client_id)
#    start_simulation({client_id, 10, total_clients})
    {:ok, state}
  end

  @impl true
  def handle_info({:client_logged_in}, state) do
    {my_id, _, simulation_mode, total_clients, follow_list} = state
    live_status = true
    state = {my_id, live_status, simulation_mode, total_clients, follow_list}
    {:noreply, state}
  end

  @impl true
  def handle_info({:tweet_posted}, state) do
    # Do nothing
    {:noreply, state}
  end

  @impl true
  def handle_info({:client_registered}, state) do
    # Do nothing
    {:noreply, state}
  end

  @impl true
  def handle_info({:client_following_successfully, follow_list}, state) do
    {my_id, live_status, simulation_mode, total_clients, _follow_list} = state
    #  tuple = :ets.lookup(:"client#{my_id}_follow_list", "follow_list")
    :ets.insert(:"client#{my_id}_follow_list", {"follow_list", follow_list})
    state = {my_id, live_status, simulation_mode, total_clients, follow_list}
    {:noreply, state}
  end

  @impl true
  def handle_info({:live_tweet, tweet, client_id}, state) do
    {my_id, _live_status, _simulation_mode, _total_clients, _follow_list} = state
    IO.puts("[user #{my_id} feed]: (live tweet from user #{client_id}) " <> tweet)
    #my_feed_tweet = "(live tweet from user #{client_id}) " <> tweet 
    #feed_print(my_id, my_feed_tweet)
    if Enum.random(1..100) < 40 do
      # Retweeting
      # Stripping multiple retweet string in case this was retweeted
      tweet = Regex.replace(~r/[^\w]*retweet:[^\w]/, tweet, "")
      retweet = "retweet: " <> tweet
      post_tweet(my_id, retweet)
    end
    {:noreply, state}
  end

  @impl true
  def handle_info(flag, state) do
    {my_id, _live_status, _simulation_mode, _total_clients, _follow_list} = state
    
    case flag do
      {:rcv_tweets_w_hashtag, hashtag, tweets} ->
			if tweets != [] and tweets != nil do 
    			  IO.puts("[user #{my_id} feed]: (queried tweet with hashtag #{hashtag}) " <> Enum.at(tweets, 0))
                        end
      {:rcv_tweets_w_mention, tweets} ->
		        if tweets != [] and tweets != nil do 
    			  IO.puts("[user #{my_id} feed]: (queried tweet with my mention) " <> Enum.at(tweets, 0))
                        end
    end  

    {:noreply, state}  
  end

  @impl true
  def handle_cast({:start_simulation, num_tweets, _total_clients}, state) do
    {my_id, live_status, simulation_mode, total_clients, follow_list} = state
    Logger.info("Client #{my_id} starting simulation")
    # check if we are alive and then start the simulation
    if live_status == true do
      start_simulation({my_id, num_tweets, total_clients})
    else
      Process.send_after(self(), {:start_simulation, num_tweets, total_clients}, 0)
    end

    state = {my_id, live_status, simulation_mode, total_clients, follow_list}
    {:noreply, state}
  end

  def post_tweet(my_id, tweet) do
    IO.puts("[user #{my_id} feed]: " <> tweet)
    #feed_print(my_id, tweet)
    send(:global.whereis_name(:twitter_simulation_server), {:post_tweet, tweet, my_id})
  end

  def start_client({client_id}) do
    # Let's start the server in a distributed node model
    # Ideally we should configure our IP using an external IP config file or
    # an environment variable. But for now, we can use a small hack that is reliable in
    # most scenarios for testing purpose. We can get an ip list and invert it and take the second last
    ip_addr = System.get_env("SERVER_IP")
    ## Check environment variable 
    ## NEED TO FIX TO READ FROM MIX CONFIG
    if ip_addr == nil do
      # No env variable, use a temp hack
      ip_list = :inet.getif() |> elem(1) |> Enum.reverse() 
      find_ip_start_node(ip_list, client_id)
    else
      start_node(ip_addr, client_id)
    end

    ## Sycing the distributed nodes so they know of other nodes presence
    :global.sync()
  end

  def register_client(client_id) do
    Logger.info("Client #{client_id} registering with server")
    send(:global.whereis_name(:twitter_simulation_server), {:register_client, client_id})
  end

  def login_client(client_id) do
    # Simulate going live by logging in
    Logger.info("Client #{client_id} has logged in")
    send(:global.whereis_name(:twitter_simulation_server), {:login_client, client_id})
  end

  def start_following(my_id, client_id) do
    send(:global.whereis_name(:twitter_simulation_server), {:add_follower, my_id, client_id})
  end

  def start_simulation({my_id, num_tweets, total_clients}) do
    ## Start following
    total_list = Enum.to_list(1..total_clients)
    follow_1 = Enum.random(total_list -- [my_id]) 
    start_following(my_id, follow_1)
    num_follow = random_normal(total_clients, 4, 4) 

    Enum.each(1..num_follow, fn _x ->
      follow = Enum.random(total_list -- [my_id] -- [follow_1]) 
      start_following(my_id, follow)
    end)

    # Send a random type of tweet either with a mention, or hashtag or normal
    tweet_mention = "user #{my_id}: @#{Enum.random(1..total_clients)} is cool"
    post_tweet(my_id, tweet_mention)
    tweet_hashtag = "user #{my_id}: #COP5615isgreat i love it"
    post_tweet(my_id, tweet_hashtag)
    Enum.each(3..num_tweets, fn _x ->
      if :random.uniform(100) < 15 do
        mention = Enum.random(1..total_clients)
	post_tweet(my_id, tweet_mention)
        #send(:global.whereis_name(:twitter_simulation_server), {:post_tweet, tweet, my_id})
      else
        if :random.uniform(100) < 15 do
          tweet = "user #{my_id}: #COP5615isgreat i love it"
	  post_tweet(my_id, tweet)
         # send(:global.whereis_name(:twitter_simulation_server), {:post_tweet, tweet, my_id})
        else
          tweet1 = "user #{my_id}: #{generate_random_string(10)} is the illuminati key"
          tweet2 = "user #{my_id}: #{generate_random_string(10)} is the a null key"
          tweet3 = "user #{my_id}: #{generate_random_string(10)} dog meme"
          tweet4 = "user #{my_id}: #{generate_random_string(10)} oh boi"
          tweet5 = "user #{my_id}: #{generate_random_string(10)} cat meme"
          tweet_list = [tweet1, tweet2, tweet3, tweet4, tweet5]
          tweet = Enum.random(tweet_list)
          post_tweet(my_id, tweet)
          #send(:global.whereis_name(:twitter_simulation_server), {:post_tweet, tweet, my_id})
        end
      end
    end)

    ## Query for hashtags & mentions
    hashtag = "#COP5615isgreat"
    query_for_hashtag_tweet(hashtag, my_id)
    query_for_mention_tweet(my_id)

  end
 
  def query_for_hashtag_tweet(hashtag, client_id) do
    send(:global.whereis_name(:twitter_simulation_server),{:find_tweets_w_hashtag, hashtag, client_id})
  end

  def query_for_mention_tweet(client_id) do
    send(:global.whereis_name(:twitter_simulation_server),{:find_tweets_w_mention, client_id})
  end

  def random_normal(limit, mean, variance) do
    val = round(:rand.normal(limit * mean / 100, limit * variance / 100) * 10)

    if val == nil or val < 0 do
      0
    else
      val
    end
  end

  def generate_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
    |> String.downcase()
  end
  
  def feed_print(my_id, tweet) do
    IO.write IO.ANSI.format([:light_green_background, :black, inspect("[user #{my_id} feed]")])
    IO.puts(tweet)
  end
  
end
