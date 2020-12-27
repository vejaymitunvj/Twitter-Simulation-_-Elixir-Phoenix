# Simulation of Twitter Enginer with client traffic

### Group Members:         
  * Muthu Kumaran Manoharan   (UFID# 9718-4490)
  * Vejay Mitun Venkatachalam Jayagopal (UFID# 3106-5997)

### PRE-REQUISITES
The following need to be installed to run the project:
 * Elixir
 * Erlang

### Steps to run code:
  * Create a new mix project using command “mix new twitter_simulator”
  * Extract zip file file containing project_4_1.exs, mix.exs, twitter_simulator.ex, twitter_simulator_client.ex, twitter_simulator_server.ex and twitter_simulator_test.exs files.
  * Copy main.exs, mix.exs to the project folder created.(Replace the default files created with ours).
  * Copy twitter_simulator.ex, twitter_simulator_client.ex, twitter_simulator_server.ex to the lib folder within the project folder.
  * Copy twitter_simulator_test.exs to the test folder within the project folder
  * IMPORTANT: Setup a environment variable "SERVER_IP" setting it to your system IP address.
	* eg: In linux, my local IP address is 10.138.0.16
		  Running the following command will set the env variable
		  `export SERVER_IP=10.138.0.16`
  *	To run the main simulation: Open cmd or terminal , run project by issuing commands “mix compile” and  “mix run –-no-halt project3.exs <# of users> <# of tweets>” for the project to run the simulation and terminate after printing the result.
    * eg #1: mix run --no-halt project_4_1.exs 5000 20
	* eg #2: mix run --no-halt project_4_1.exs 1000 200
	* eg #3  mix run --no-halt project_4_1.exs 1000 500
  * To run the test: Open cmd or terminal, issue the following command: `mix test'. This runs the 18 test cases which involves the following tests:
		1. Client registration.
		2. Client login.
		3. Client deletion.(3 test cases)
		4. Client following capability check.(3 test cases)
		5. Client live tweeting capability check.
		6. Tweeting with mentions.(3 test cases)
		7. Tweeting with hashtags.(3 test cases)
		8. Tweet querying capability.(3 test cases)

#### What is working :

As per the project requirement, We have created a central twitter server engine which keep tracks of the clients and distribute their tweets. The server is a single GenServer process and the clients are individual Genserver processes. 
We have implemented the following functionalities for the client:
	1. Register account.
	2. Delete account.
	3. Following other accounts.
	4. Post tweets with hashtags and mention. When a tweet is posted with a mention, the mentioned user is notified by getting the tweet and only the original tweet is sent to the user i.e if someone else retweets this, the mentioned user is not notified again.
	5. Retweeting a tweet.
	6. Live delivery of tweets to live users.
	7. Querying of a tweet with specific hashtags or with the user mentions.
	

##### Code working brief explanation:
	* The TwitterSimulation.Server is the twitter enginer which keep tracks of the clients using ETS tables.
	* When a client tries to register or login or delete it's account, it sends a request via message to the server and the server takes care of it.
	* When a client tries to follow another client, it sends a request via message to the server with the id of the account which the client is going to follow. The twitter engine updates it's ets table of both the requesting client(say client 1) and the client which is being followed(say client 2) so any tweets by the client 2 get delivered to client 1 if it's online.
	* When a client post's a tweet, it get sent to it's followers where it's displayed on the followers feed. If the tweet contains mentions, those menitoned users are also notified and get the tweet. If the tweet contains hashtag or mentions, they are tracked by the twitter engine for easy access when required.
	* Retweeting is simple as tweeting but the server makes sure the mentioned user, if the tweet has mentions, is not notified multiple times and only the orignal tweet is being retweeted. 
	* When a client wants to query a tweet with particular hashtag or mentions or it's own records, it sends a tweet query request to the server which fetches and sends the result back to the client.




	
###### Tested for maximum number of nodes:

NO OF USERS  		NO OF TWEETS 		 	      Time Taken
-----------   	-----------------------		      ----------
100						100							1321 ms
1000					100							99691 ms			   
1000			   		1000		                83 min
