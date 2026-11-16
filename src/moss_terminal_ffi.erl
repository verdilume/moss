-module(moss_terminal_ffi).
-export([stdout_is_tty/0, getenv/1, query_background/1]).

stdout_is_tty() ->
    case io:getopts() of
        Opts when is_list(Opts) -> proplists:get_bool(stdout, Opts);
        _ -> false
    end.

getenv(Name) ->
    unicode:characters_to_binary(os:getenv(binary_to_list(Name), "")).

query_background(Script) ->
    case {os:type(), io:getopts()} of
        {{unix, _}, Opts} when is_list(Opts) ->
            case proplists:get_bool(stdin, Opts) of
                true ->
                    case global:trans({?MODULE, self()}, fun() -> run_probe(Script) end, [node()], 0) of
                        aborted -> <<>>;
                        Reply -> Reply
                    end;
                false -> <<>>
            end;
        _ -> <<>>
    end.

run_probe(Script) ->
    % With nouse_stdio the child inherits the TTY, and fd 4 returns the reply.
    Command = <<"exec 5<&0; exec 6>&1; exec 1>&4; exec 4>&-\n", Script/binary>>,
    try open_port({spawn_executable, "/bin/sh"}, [binary, exit_status, nouse_stdio,
            {args, ["-c", Command]}]) of
        Port ->
            Deadline = erlang:monotonic_time(millisecond) + 400,
            Bytes = collect(Port, Deadline, <<>>),
            case erlang:port_info(Port) of
                undefined -> ok;
                _ -> try erlang:port_close(Port) catch error:badarg -> ok end
            end,
            unicode:characters_to_binary(Bytes, latin1)
    catch error:_ -> <<>>
    end.

collect(Port, Deadline, Bytes) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Port, {data, Data}} -> collect(Port, Deadline, <<Bytes/binary, Data/binary>>);
        {Port, {exit_status, _Status}} -> Bytes
    after Remaining -> Bytes
    end.
