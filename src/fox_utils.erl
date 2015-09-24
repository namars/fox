-module(fox_utils).

-export([name_to_atom/1,
         map_to_params_network/1,
         params_network_to_str/1,
         validate_params_network_types/1]).

-include("fox.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").


%%% module API

-spec name_to_atom(connection_name()) -> atom().
name_to_atom(Name) when is_binary(Name) ->
    name_to_atom(erlang:binary_to_atom(Name, utf8));
name_to_atom(Name) when is_list(Name) ->
    name_to_atom(list_to_atom(Name));
name_to_atom(Name) -> Name.


-spec map_to_params_network(map()) -> #amqp_params_network{}.
map_to_params_network(Params) when is_map(Params) ->
    #amqp_params_network{
       host = maps:get(host, Params),
       port = maps:get(port, Params),
       virtual_host = maps:get(virtual_host, Params),
       username = maps:get(username, Params),
       password = maps:get(password, Params),
       heartbeat = maps:get(heartbeat, Params, 10),
       connection_timeout = maps:get(connection_timeout, Params, 10),
       channel_max = maps:get(channel_max, Params, 0),
       frame_max = maps:get(frame_max, Params, 0),
       ssl_options = maps:get(ssl_options, Params, none),
       auth_mechanisms = maps:get(auth_mechanisms, Params,
                                  [fun amqp_auth_mechanisms:plain/3,
                                   fun amqp_auth_mechanisms:amqplain/3]),
       client_properties = maps:get(client_properties, Params, []),
       socket_options = maps:get(socket_options, Params, [])
      }.


-spec params_network_to_str(#amqp_params_network{}) -> iolist().
params_network_to_str(#amqp_params_network{host = Host,
                                           port = Port,
                                           virtual_host = VHost,
                                           username = Username}) ->
    io_lib:format("~s@~s:~p~s", [Username, Host, Port, VHost]).


-spec validate_params_network_types(#amqp_params_network{}) -> true.
validate_params_network_types(
  #amqp_params_network{
     host = Host,
     port = Port,
     virtual_host = VirtualHost,
     username = UserName,
     password = Password,
     heartbeat = Heartbeat,
     connection_timeout = Timeout,
     channel_max = ChannelMax,
     frame_max = FrameMax,
     ssl_options = SSL_Options,
     auth_mechanisms = AuthMechanisms,
     client_properties = ClientProperties,
     socket_options = SocketOptions
    }) ->
    if
        not is_list(Host) -> throw({invalid_amqp_params_network, "host should be string"});
        not is_integer(Port) -> throw({invalid_amqp_params_network, "port should be integer"});
        not is_binary(VirtualHost) -> throw({invalid_amqp_params_network, "virtual_host should be binary"});
        not is_binary(UserName) -> throw({invalid_amqp_params_network, "username should be binary"});
        not is_binary(Password) -> throw({invalid_amqp_params_network, "password should be binary"});
        not is_integer(Heartbeat) -> throw({invalid_amqp_params_network, "heartbeat should be integer"});
        not is_integer(Timeout) -> throw({invalid_amqp_params_network, "connection_timeout should be integer"});
        not is_integer(ChannelMax) -> throw({invalid_amqp_params_network, "channel_max should be integer"});
        not is_integer(FrameMax) -> throw({invalid_amqp_params_network, "frame_max should be integer"});
        not (SSL_Options == none orelse is_list(SSL_Options)) ->
            throw({invalid_amqp_params_network, "ssl_options should be list or none"});
        not is_list(AuthMechanisms) -> throw({invalid_amqp_params_network, "auth_mechanisms should be list"});
        not is_list(ClientProperties) -> throw({invalid_amqp_params_network, "client_properties should be list"});
        not is_list(SocketOptions) -> throw({invalid_amqp_params_network, "socket_options should be list"});
        true -> true
    end.