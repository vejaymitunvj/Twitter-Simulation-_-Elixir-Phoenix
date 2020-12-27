################################# START OF APP ######################################
################################## START OF TwitterSimulator ######################################
######################################################################################
###                                                                                 ##
### Description: The application module which accepts the commandline arguments     ##
###              and starts the main engine                                         ##
###                                                                                 ##
###                                                                                 ##
###                                                                                 ##
###                                                                                 ##
######################################################################################
defmodule TwitterSimulator do
  @moduledoc """
  Documentation for TwitterSimulator. This is the main function via which we are gonna run the simulator.
  Two form of input arguments will be provided, one with 0 arguments to start the server & another with 2 arguments to run
  the client simulation
  """

  @doc """

  ## Examples
  """
  def main(args) do
    {_debug_opt, argv, []} = OptionParser.parse(args)
    {num_user, ""} = argv |> Enum.at(0) |> Integer.parse(10)
    {num_tweets, ""} = argv |> Enum.at(1) |> Integer.parse(10)
    start_time = System.system_time(:millisecond)
    start_server({num_user, num_tweets})
    IO.puts("Starting the clients")
    start_clients(num_user, num_user)
    
  end

  def start_server({total_users, num_tweets}) do
    TwitterSimulator.Server.start_link({total_users, num_tweets, true})
  end

  def start_clients(num_user, total_clients) do
    ## Start the registry to store the client IDs
    :ets.new(:client_ids, [:set, :public, :named_table])
    ## Creating users
    spawn_clients(num_user, total_clients)
  end

  def spawn_clients(num_user, total_clients) do
    # Let's keep the number as their user IDs for ease of reference
    client_id = Integer.to_string(num_user)
    client_pid = spawn( fn -> TwitterSimulator.Client.start_link(client_id, total_clients)end)
    :ets.insert(:client_ids, {client_id, client_pid})

    if num_user > 1 do
      spawn_clients(num_user - 1, total_clients)
    end
  end

end
