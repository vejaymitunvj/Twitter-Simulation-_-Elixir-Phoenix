################################# START OF APP ######################################
################################### START OF TwitterSimulator ######################################
#######################################################################################
####                                                                                 ##
#### Description: The application module which accepts the commandline arguments     ##
####              and starts the twitter engine                                      ##
####                                                                                 ##
####                                                                                 ##
####                                                                                 ##
####                                                                                 ##
#######################################################################################

defmodule TwitterSimulator.Server do
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

  def start_link({total_users, num_tweets, simulation_mode}) do
    GenServer.start_link(__MODULE__, {total_users, num_tweets, simulation_mode})
  end

  def start_node(ip_addr) do
    server_node = String.to_atom("server@" <> ip_addr)
    Node.start(server_node)
    Node.set_cookie(server_node, :hakuna)
    Logger.info("Starting Twitter Simulation Server")
  end

  def find_ip_start_node(ip_list) do
    [head | tail] = ip_list

    unless Node.alive?() do
      try do
        {possible_ip, _, _} = head
        ip = to_string(:inet_parse.ntoa(possible_ip))

        if ip == "127.0.0.1" do
          if length(ip_list) > 1 do
            find_ip_start_node(tail)
          else
            Logger.warn("Unable to start the server node in a distributed mode")
          end
        else
          start_node(ip)
        end
      rescue
        _e ->
          if length(ip_list) > 1 do
            find_ip_start_node(tail)
          else
            Logger.warn("Unable to start the server node in a distributed mode")
          end
      end
    end
  end

  @impl true
  def init({total_users, num_tweets, simulation_mode}) do
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
      find_ip_start_node(ip_list)
    else
      start_node(ip_addr)
      :global.sync()
    end

    :global.register_name(:twitter_simulation_server, self())

    # Let's create the ETS tables to track the clients registered,
    # clients that are followed by the client being passed,
    # clients that are subscibred to the client being passed,
    # tweets of a particular client
    # tweets with a paticular hash tag
    # tweets with a particular mentions 
    :ets.new(:registered_clients, [:set, :public, :named_table])
    :ets.new(:alive_clients, [:set, :public, :named_table])
    :ets.new(:followers_of, [:set, :public, :named_table])
    :ets.new(:subscribed_to, [:set, :public, :named_table])
    :ets.new(:tweets, [:set, :public, :named_table])
    :ets.new(:tweets_w_hashtags, [:set, :public, :named_table])
    :ets.new(:tweets_w_mentions, [:set, :public, :named_table])
    IO.puts("Server started")
    Process.send_after(self(), {:ready_for_simulation}, 100)
    {:ok, {total_users, num_tweets, 0, simulation_mode}}
  end

  @impl true
  def handle_cast({:status_update, client_id}, state) do
    {total_users, num_tweets, num_registered_users, simulation_mode} = state
    register_client_ack(client_id)
    num_registered_users = num_registered_users + 1
    state = {total_users, num_tweets, num_registered_users, simulation_mode}
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_reg_clients, sender_pid}, _from, state) do
    output = get_reg_clients()
    send(sender_pid, {:reg_clients_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:get_live_clients, sender_pid}, _from, state) do
    output = get_live_clients()
    send(sender_pid, {:live_clients_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:delete_client, client_id, sender_pid}, _from, state) do
    output = delete_client_noack(client_id)
    send(sender_pid, {:delete_clients_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:direct_live_tweet, client_id, tweet, sender_pid}, _from, state) do
    output = if client_online?(client_id) do
      send(:global.whereis_name(:"client_#{client_id}"), {:live_tweet, tweet, client_id})
    end
    send(sender_pid, {:direct_live_tweet_sent, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:query_client_tweets, client_id, sender_pid}, _from, state) do
    val = :ets.lookup(:tweets, client_id)
        output = if val == [] do
	        []
	      else
	        [{_, old_tweets}] = val
	        old_tweets
	      end
    send(sender_pid, {:query_client_tweets_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:get_tweet_w_mention, mention_id, sender_pid}, _from, state) do
   mentioned_tweets_tuple = :ets.lookup(:tweets_w_mentions, "@" <> mention_id)

   output =
     if mentioned_tweets_tuple == [] do
        []
      else
        [{_, tweets}] = mentioned_tweets_tuple
        tweets
      end

    send(sender_pid, {:mention_clients_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:get_tweet_w_hashtag, hashtag, sender_pid}, _from, state) do
   hashtag_tweets_tuple = :ets.lookup(:tweets_w_mentions, hashtag)

   output =
     if hashtag_tweets_tuple == [] do
        []
      else
        [{_, tweets}] = hashtag_tweets_tuple
        tweets
      end

    send(sender_pid, {:hashtag_clients_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_call({:get_follow_list, req_client_id, sender_pid}, _from, state) do
    output = if :ets.lookup(:subscribed_to, req_client_id) == [] do
        []
     else
       [{_, old_list}] = :ets.lookup(:subscribed_to, req_client_id)
        old_list
     end
    send(sender_pid, {:follow_list_out, output})
    {:reply, output, state}
  end

  @impl true
  def handle_info({:ready_for_simulation}, state) do
    {total_clients, num_tweets, num_registered_users, simulation_mode} = state

    if num_registered_users == total_clients and simulation_mode == true do
      Logger.info IO.ANSI.format([:light_green_background, :black, ("Starting simulation")])
      start_simulation_for_all(total_clients, num_tweets, total_clients)
      Process.send_after(self(), {:check_for_empty_box, System.system_time(:millisecond), 0}, 100)
    else
      Process.send_after(self(), {:ready_for_simulation}, 100)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:check_for_empty_box, start_time, check_again}, state) do
    {total_clients, num_tweets, num_registered_users, simulation_mode} = state

    result_list =
      Enum.map(1..total_clients, fn client ->
        val = :global.whereis_name(:"client_#{client}") 
        out = if val == :undefined || val == nil do
          0 + :erlang.process_info(self())[:message_queue_len] - 1
        else
         # [{_, user_pid}] = val
          ret = :erlang.process_info(val)[:message_queue_len]
          ret + :erlang.process_info(val)[:message_queue_len] - 1
        end
        out
      end)
     if Enum.sum(result_list) > 0 do
         Process.send_after(self(), {:check_for_empty_box, start_time, check_again}, 1000)
      else
        if check_again < 3 do
          Process.send_after(self(), {:check_for_empty_box, start_time, check_again + 1}, 1000)
        else
          end_time = System.system_time(:millisecond)
          total_time = end_time - start_time - 3000
          Logger.info IO.ANSI.format([:light_green_background, :black, ("Total time taken for simulation: #{total_time} ms")])
	  Process.sleep(100)
          System.halt(0)
        end
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(flag, state) do
    case flag do
      {:register_client, client_id} ->
        # register_client_ack(client_id)
        GenServer.cast(self(), {:status_update, client_id})

      {:delete_client, client_id} ->
        delete_client_noack(client_id)

      {:login_client, client_id} ->
        client_login_ack(client_id)

      {:logout_client, client_id} ->
        client_logout_ack(client_id)

      {:add_follower, req_client_id, follow_client_id} ->
        update_subscribed_to_list_noack(follow_client_id, req_client_id)
        update_followers_of_list_ack(req_client_id, follow_client_id)

      {:get_tweets, client_id} ->
        get_tweets_ack(client_id)

      {:post_tweet, tweet, client_id} ->
        post_tweet_ack(tweet, client_id)

      {:find_tweets_w_hashtag, hashtag, client_id} ->
        find_hastag_tweets_ack(hashtag, client_id)

      {:find_tweets_w_mention, client_id} ->
        find_tweets_w_mention_ack(client_id)

      _ ->
        IO.puts("Unknown request #{inspect(flag)}")
    end

    {:noreply, state}
  end

  def start_simulation_for_all(num_user, num_tweets, total_clients) do
    GenServer.cast(
      :global.whereis_name(:"client_#{num_user}"),
      {:start_simulation, num_tweets, total_clients}
    )

    if num_user > 1 do
      start_simulation_for_all(num_user - 1, num_tweets, total_clients)
    end
  end

  def register_client_ack(client_id) do
    # Register the client by updating the central table with it's ID & initialize the followers_of, subscribed_to & tweets list
    :ets.insert(:registered_clients, {client_id, true})
    # It's possible for delete & re-register a user, we are maintaining the followers list as such
    if :ets.lookup(:followers_of, client_id) == [] do
      :ets.insert(:followers_of, {client_id, []})
    end

    :ets.insert(:subscribed_to, {client_id, []})
    :ets.insert(:tweets, {client_id, []})
    IO.puts("client #{client_id} is getting registered")
    # Send ACK
    send(:global.whereis_name(:"client_#{client_id}"), {:client_registered})
  end

  def get_reg_clients() do
    reg_client_list = :ets.tab2list(:registered_clients)
  end

  def get_live_clients() do
    alive_client_list = :ets.tab2list(:alive_clients)
  end

  def delete_client_noack(client_id) do
    :ets.delete(:registered_clients, client_id)

    ## Twitter follower's still follow your account but won't be able to see your tweets unless you reactivate it,
    ## so let's not delete this id from this client's followers table
  end

  def client_login_ack(client_id) do
    :ets.insert(:alive_clients, {client_id, true})
    IO.puts("client #{client_id} logged in")
    send(:global.whereis_name(:"client_#{client_id}"), {:client_logged_in})
  end

  def client_logout_ack(client_id) do
    :ets.delete(:alive_clients, client_id)
    send(:global.whereis_name(:"client_#{client_id}"), {:client_logged_out})
  end

  def update_followers_of_list_ack(req_client_id, follow_client_id) do
    output = :ets.lookup(:followers_of, follow_client_id)

    old_list =
      if output == [] do
        []
      else
        [{_, old_list}] = output
        old_list
      end

    new_list = [req_client_id] ++ old_list
    :ets.insert(:followers_of, {follow_client_id, new_list})

    send(
      :global.whereis_name(:"client_#{req_client_id}"),
      {:client_following_successfully, new_list}
    )
  end

  def update_subscribed_to_list_noack(follow_client_id, req_client_id) do
    if :ets.lookup(:subscribed_to, req_client_id) == [] do
      :ets.insert(:subscribed_to, {req_client_id, [follow_client_id]})
    else
      [{_, old_list}] = :ets.lookup(:subscribed_to, req_client_id)
      new_list = [follow_client_id] ++ old_list
      :ets.insert(:subscribed_to, {req_client_id, new_list})
    end
  end

  def get_tweets_ack(client_id) do
    tweets =
      if :ets.lookup(:tweets, client_id) == [] do
        []
      else
        [{_, tweets}] = :ets.lookup(:tweets, client_id)
        tweets
      end

    send(:global.whereis_name(:"client_#{client_id}"), {:client_tweets, tweets})
  end

  def post_tweet_ack(tweet, client_id) do
    val = :ets.lookup(:tweets, client_id)
    old_tweets = if val == [] do
      [] 
    else
      [{_, old_tweets}] = val
      old_tweets
    end
    new_tweets = [tweet] ++ old_tweets
    :ets.insert(:tweets, {client_id, new_tweets})
    ## Check for hashtags & mentions using regex   
    hashtag_list = Regex.scan(~r/\B#[\w]+/, tweet) |> Enum.concat()
    mention_list = Regex.scan(~r/\B@[\w]+/, tweet) |> Enum.concat()

    if hashtag_list != [] do
      Enum.each(hashtag_list, fn hashtag ->
        update_hastag_tweets_list(hashtag, tweet)
      end)
    end

    ## If someone has been mentioned, this tweet must also be delivered to them
    if mention_list != [] do
      Enum.each(mention_list, fn mention ->
        update_mention_tweets_list(mention, tweet)
        client = String.slice(mention, 1, String.length(mention) - 1)

        ## Check if the client is online and whether this was a retweet
        if client_online?(client) and Regex.match?(~r/[^\w]*retweet:[^\w]/, tweet) == false do
          send(:global.whereis_name(:"client_#{client}"), {:live_tweet, tweet, client_id})
        end
      end)
    end

    ## Deliver the tweets to the live followers
    if :ets.lookup(:followers_of, client_id) != [] do
      [{_, followers}] = :ets.lookup(:followers_of, client_id)
      distribute_tweets_to_live_clients(followers, tweet, client_id)
    end

    # Send ACK
    send(:global.whereis_name(:"client_#{client_id}"), {:tweet_posted})
  end

  def distribute_tweets_to_live_clients(client_list, tweet, sender_client) do
    Enum.each(client_list, fn client ->
      if client_online?(client),
        do: send(:global.whereis_name(:"client_#{client}"), {:live_tweet, tweet, sender_client})
    end)
  end

  def client_online?(client_id) do
    if :ets.lookup(:alive_clients, client_id) == [] do
      false
    else
      true
    end
  end

  def update_hastag_tweets_list(hashtag, tweet) do
    hashtag_tweets_tuple = :ets.lookup(:tweets_w_hashtags, hashtag)

    new_list =
      if hashtag_tweets_tuple == [] do
        [tweet]
      else
        [{_, old_list}] = hashtag_tweets_tuple
        [tweet] ++ old_list
      end

    :ets.insert(:tweets_w_hashtags, {hashtag, new_list})
  end

  def update_mention_tweets_list(mention, tweet) do
    mention_tweets_tuple = :ets.lookup(:tweets_w_mentions, mention)

    new_list =
      if mention_tweets_tuple == [] do
        [tweet]
      else
        [{_, old_list}] = mention_tweets_tuple
        [tweet] ++ old_list
      end

    :ets.insert(:tweets_w_mentions, {mention, new_list})
  end

  def find_hastag_tweets_ack(hashtag, client_id) do
    hashtag_tweets_tuple = :ets.lookup(:tweets_w_hashtags, hashtag)

    tweets =
      if hashtag_tweets_tuple == [] do
        []
      else
        [{_, tweets}] = hashtag_tweets_tuple
        tweets
      end

    send(:global.whereis_name(:"client_#{client_id}"), {:rcv_tweets_w_hashtag, hashtag, tweets})
  end

  def find_tweets_w_mention_ack(client_id) do
    mentioned_tweets_tuple = :ets.lookup(:tweets_w_mentions, "@" <> to_string(client_id))

    tweets =
      if mentioned_tweets_tuple == [] do
        []
      else
        [{_, tweets}] = mentioned_tweets_tuple
        tweets
      end

    send(:global.whereis_name(:"client_#{client_id}"), {:rcv_tweets_w_mention, tweets})
  end
end
