-module(chat_zone).
-behaviour(ow_zone).

-export([
         start_link/0,
         stop/0,
         join/2,
         part/2,
         channel_msg/2
        ]).

-export([init/1,
         handle_join/4,
         handle_part/4,
         handle_channel_msg/4,
         handle_tick/2
        ]).

-define(SERVER, ?MODULE).

-rpc_client([sync, channel_msg]). % Server -> Client
-rpc_server([join, part, channel_msg]). % Client -> Server 

start_link() ->
    ow_zone:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
    ow_zone:stop(?SERVER).

join(Msg, Who) ->
    ow_zone:join(?SERVER, Msg, Who).
part(Msg, Who) ->
    ow_zone:part(?SERVER, Msg, Who).
channel_msg(Msg, Who) ->
    ow_zone:rpc(?SERVER, channel_msg, Msg, Who).

init([]) ->
    State = #{},
    Config = #{},
    {ok, State, Config}.

handle_join(Msg, Who, _ZD, State) ->
    % A player has joined, get their handle (if it exists), otherwise make it
    % Unknown[ID]
    SessionID = ow_session:id(Who),
    Handle = maps:get(handle, Msg, "Unknown" ++ integer_to_list(SessionID)),
    logger:notice("Player ~p (~p) has joined the chat.", [Handle,
                                                              Who]),
    % Store the player's handle in the server state, using their session ID
    % as a key. This is probably the most convenient but not necessarily the
    % most efficient representation.
    State1 = State#{ Who => Handle },
    % Get a list of handles
    Handles = maps:values(State1),
    % Broadcast a sync message to all clients with handles for the user list
    BcastMsg = {sync, #{ handles => Handles }},
    {broadcast, BcastMsg, State1}.
handle_part(_Msg, Who, _ZD, State) ->
    % Get the player's handle from the internal chat zone's state.
    #{ Who := Handle } = State,
    logger:notice("Player ~p (~p) has left the chat.", [Handle,
                                                            Who]),
    % Make sure to delete the key from the state map
    State1 = maps:remove(Who, State),
    % Get the list of handles from the state map
    Handles = maps:values(State1),
    % Broadcast a sync message to all clients with handles for the user list
    BcastMsg = {sync, #{ handles => Handles }},
    {broadcast, BcastMsg, State1}.
handle_channel_msg(Msg, Who, _ZD, State) ->
    #{ Who := Handle } = State,
    logger:notice("<~p>: ~p", [Handle, Msg]),
    % We want to overwrite any handle the client might have sent with the one
    % we have in our zone state 
    Msg1 = Msg#{ handle => Handle },
    ow_zone:broadcast(?SERVER, {channel_msg, Msg1}),
    {noreply, State}.
handle_tick(_ZoneData, State) ->
    % The processing tick. We can act on all of the relevant internal state
    % here
    {noreply, State}.
