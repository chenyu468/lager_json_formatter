-module(lager_json_formatter).

-include_lib("lager/include/lager.hrl").

-export([format/2, format/3]).

-spec format(lager_msg:lager_msg(),list(),any()) -> any().
format(Msg, Config, _) ->
  format(Msg, Config).

-spec format(lager_msg:lager_msg(),list()) -> any().
format(Msg, Config) ->
  Encoder = mochijson3:encoder([
    {handler, fun json_handler/1},
    {utf8, proplists:get_value(utf8, Config, true)}
  ]),
  [Encoder(Msg), <<"\n">>].

-spec json_handler(lager_msg:lager_msg()) -> any().
json_handler(Msg) ->
    {Date, Time} = lager_msg:datetime(Msg),
    Metadata = [ {K, make_printable(V)} || {K, V} <- lager_msg:metadata(Msg)],
    Msg_2 = trim(lager_msg:message(Msg)),
    Equipment_uid = case  application:get_env(fish,mq_username) of
                        undefined ->
                            undefined;
                        {ok,Value} ->
                            Value
                    end,
    Local_ip = case  application:get_env(fish,local_ip) of
                        undefined ->
                            undefined;
                        {ok,Value_a} ->
                            Value_a
                    end,
    {struct, [
              {<<"@timestamp">>, iolist_to_binary([Date, $T, Time, $Z])},
              {message, to_binary(Msg_2)},
              {level, severity_to_binary(lager_msg:severity(Msg))},
              {level_as_int, lager_msg:severity_as_int(Msg)},
              {destinations, lager_msg:destinations(Msg)},
              {equipment_uid, to_binary(Equipment_uid)},
              {local_ip, to_binary(Local_ip)}
              | Metadata]}.

to_binary(V) when is_binary(V) ->
    V;
to_binary(V) when is_list(V) ->
    try
        list_to_binary(V)
    catch
        _:_ ->
            list_to_binary(io_lib:format("~p", [V]))
    end;
to_binary(V) when is_atom(V) ->
    list_to_binary(atom_to_list(V));
to_binary(V) ->
    list_to_binary(io_lib:format("~p", [V])).


make_printable(A) when is_atom(A) orelse is_binary(A) orelse is_number(A) -> A;
make_printable(P) when is_pid(P) -> iolist_to_binary(pid_to_list(P));
make_printable(Other) -> iolist_to_binary(io_lib:format("~p",[Other])).

severity_to_binary(debug)     -> <<"DEBUG">>;
severity_to_binary(info)      -> <<"INFO">>;
severity_to_binary(notice)    -> <<"NOTICE">>;
severity_to_binary(warning)   -> <<"WARNING">>;
severity_to_binary(error)     -> <<"ERROR">>;
severity_to_binary(critical)  -> <<"CRITICAL">>;
severity_to_binary(alert)     -> <<"ALERT">>;
severity_to_binary(emergency) -> <<"EMERGENCY">>.

trim(String) ->
    String2 = lists:dropwhile(fun is_whitespace/1, String),
    lists:reverse(lists:dropwhile(fun is_whitespace/1, lists:reverse(String2))).

% Is a character whitespace?
is_whitespace($\s) -> true;
is_whitespace($\t) -> true;
is_whitespace($\n) -> true;
is_whitespace($\r) -> true;
is_whitespace(_Else) -> false.
