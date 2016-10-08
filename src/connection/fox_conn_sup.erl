-module(fox_conn_sup).
-behaviour(supervisor).

-export([start_link/3, init/1, create_channel/1, subscribe/2, unsubscribe/2, stop/1]).

-include("otp_types.hrl").
-include("fox.hrl").


%% Module API

-spec start_link(#amqp_params_network{}, map(), integer()) -> {ok, pid()} | {error, term()}.
start_link(ConnectionParams, OtherParams, PoolSize) ->
    supervisor:start_link(?MODULE, {ConnectionParams, OtherParams, PoolSize}).


-spec init(gs_args()) -> sup_init_reply().
init({ConnectionParams, OtherParams, PoolSize}) ->
    Spec = fun(Id) ->
                   {{fox_conn_worker, Id},
                    {fox_conn_worker, start_link, [ConnectionParams, OtherParams]},
                    transient, 2000, worker,
                    [fox_conn_worker]}
           end,
    Childs = [Spec(Id) || Id <- lists:seq(1, PoolSize)],
    {ok, {{one_for_one, 10, 60}, Childs}}.


-spec create_channel(pid()) -> {ok, pid()} | {error, atom()}.
create_channel(SupPid) ->
    case get_less_busy_connection(SupPid) of
        {ok, Worker} -> fox_conn_worker:create_channel(Worker);
        {error, Reason} -> {error, Reason}
    end.


-spec subscribe(pid(), #subscription{}) -> {ok, reference()} | {error, term()}.
subscribe(SupPid, Sub) ->
    case get_less_busy_connection(SupPid) of
    {ok, Worker} ->
            fox_conn_worker:subscribe(Worker, Sub);
        {error, Reason} -> {error, Reason}
    end.


-spec unsubscribe(pid(), reference()) -> ok | {error, term()}.
unsubscribe(SupPid, Ref) ->
    Res = lists:map(fun({_, ChildPid, _, _}) ->
                            fox_conn_worker:unsubscribe(ChildPid, Ref)
                    end,
                    supervisor:which_children(SupPid)),
    case lists:member(ok, Res) of
        true -> ok;
        false -> {error, connection_not_found}
    end.


-spec stop(pid()) -> ok.
stop(SupPid) ->
    lists:foreach(fun({_, ChildPid, _, _}) ->
                          fox_conn_worker:stop(ChildPid)
                  end,
                  supervisor:which_children(SupPid)),
    ok.


%% Inner functions

-spec get_less_busy_connection(pid()) -> {ok, pid()} | {error, atom()}.
get_less_busy_connection(SupPid) ->
    {ok, MaxChannels} = application:get_env(fox, max_channels_per_connection),
    {NumChannels, Pid} = hd(lists:sort(
                              lists:map(
                                fun({_, ChildPid, _, _}) ->
                                        case fox_conn_worker:get_info(ChildPid) of
                                            {num_channels, Num} -> {Num, ChildPid};
                                            no_connection -> {infinity, ChildPid}
                                        end
                                end,
                                supervisor:which_children(SupPid)))),
    if
        NumChannels == infinity -> {error, no_connection};
        NumChannels < MaxChannels -> {ok, Pid};
        true -> {error, channels_limit_exceeded}
    end.