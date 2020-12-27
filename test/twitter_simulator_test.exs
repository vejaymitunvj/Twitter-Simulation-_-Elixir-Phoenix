defmodule TwitterSimulatorTest do
  use ExUnit.Case
  doctest TwitterSimulator
  import TwitterSimulator
  import TwitterSimulator.Server
  import TwitterSimulator.Client

  setup do
    total_users = 3
    num_tweets = 10
    TwitterSimulator.Server.start_link({total_users, num_tweets, false})
    spawn( fn -> TwitterSimulator.Client.start_link(1, total_users)end)
    spawn( fn -> TwitterSimulator.Client.start_link(2, total_users)end)
    spawn( fn -> TwitterSimulator.Client.start_link(3, total_users)end)
    ip_addr = System.get_env("SERVER_IP")
    my_node = String.to_atom("test@" <> ip_addr)
    server_node = String.to_atom("server@" <> ip_addr)
    unless Node.alive?() do
      Node.start(my_node)
      Node.set_cookie(my_node, :hakuna)
    end
    Node.connect(server_node)
    :global.sync()
    Process.sleep(200)
  end

  test "Checking client registration" do
    reg_list =
      GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_reg_clients, self()})
      assert_received {:reg_clients_out, _output}
    :ok
  end

  test "Testing client login" do
    reg_list = 
      GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_live_clients, self()})
    assert_received {:live_clients_out, _output}
    :ok
  end

  test "Testing client following capability of client 1" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_follow_list, "1", self()})
    assert_received {:follow_list_out, _output}
    :ok
  end

  test "Testing client following capability of client 2" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_follow_list, "2", self()})
    assert_received {:follow_list_out, _output}
    :ok
  end

  test "Testing client following capability of client 3" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_follow_list, "3", self()})
    assert_received {:follow_list_out, _output}
    :ok
  end

  test "Testing tweet with mentions of user 1" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_mention, "1", self()})
    assert_received {:mention_clients_out, _output}
    :ok
  end

  test "Testing tweet with mentions of user 2" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_mention, "2", self()})
    assert_received {:mention_clients_out, _output}
    :ok
  end

  test "Testing tweet with mentions of user 3" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_mention, "3", self()})
    assert_received {:mention_clients_out, _output}
    :ok
  end

  test "Testing tweet with hashtag of user 1" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_hashtag, "#COP5615isgreat", self()})
    assert_received {:hashtag_clients_out, _output}
    :ok
  end

  test "Testing tweet with hashtag of user 2" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_hashtag, "#COP5615isgreat", self()})
    assert_received {:hashtag_clients_out, _output}
    :ok
  end

  test "Testing tweet with hashtag of user 3" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:get_tweet_w_hashtag, "#COP5615isgreat", self()})
    assert_received {:hashtag_clients_out, _output}
    :ok
  end

  test "Testig live tweeting capability" do
    spawn( fn -> TwitterSimulator.Client.start_link(4, 4)end)
    Process.sleep(5000)
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:direct_live_tweet, 4, "This is testing", self()})
    Process.sleep(1000)
    assert_received {:direct_live_tweet_sent, _output}
    :ok
  end

  test "Testing tweet querying capability of 1" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:query_client_tweets, "1", self()})
    assert_received {:query_client_tweets_out, _output}
    :ok
  end

  test "Testing tweet querying capability of 2" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:query_client_tweets, "2", self()})
    assert_received {:query_client_tweets_out, _output}
    :ok
  end

  test "Testing tweet querying capability of 3" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:query_client_tweets, "3", self()})
    assert_received {:query_client_tweets_out, _output}
    :ok
  end

  test "Testing client deletion 1" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:delete_client, "1", self()})
    assert_received {:delete_clients_out, true}
    :ok
  end

  test "Testing client deletion 2" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:delete_client, "2", self()})
    assert_received {:delete_clients_out, true}
    :ok
  end

  test "Testing client deletion 3" do
    GenServer.call(:global.whereis_name(:twitter_simulation_server), {:delete_client, "3", self()})
    assert_received {:delete_clients_out, true}
    :ok
  end
end
