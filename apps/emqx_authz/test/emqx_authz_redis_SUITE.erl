%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_authz_redis_SUITE).

-compile(nowarn_export_all).
-compile(export_all).

-include("emqx_authz.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-define(CONF_DEFAULT, <<"authorization: {sources: []}">>).

all() ->
    emqx_ct:all(?MODULE).

groups() ->
    [].

init_per_suite(Config) ->
    meck:new(emqx_schema, [non_strict, passthrough, no_history, no_link]),
    meck:expect(emqx_schema, fields, fun("authorization") ->
                                             meck:passthrough(["authorization"]) ++
                                             emqx_authz_schema:fields("authorization");
                                        (F) -> meck:passthrough([F])
                                     end),

    meck:new(emqx_resource, [non_strict, passthrough, no_history, no_link]),
    meck:expect(emqx_resource, create, fun(_, _, _) -> {ok, meck_data} end ),
    meck:expect(emqx_resource, remove, fun(_) -> ok end ),

    ok = emqx_config:init_load(emqx_authz_schema, ?CONF_DEFAULT),
    ok = emqx_ct_helpers:start_apps([emqx_authz]),

    {ok, _} = emqx:update_config([authorization, cache, enable], false),
    {ok, _} = emqx:update_config([authorization, no_match], deny),
    Rules = [#{<<"type">> => <<"redis">>,
               <<"server">> => <<"127.0.0.1:27017">>,
               <<"pool_size">> => 1,
               <<"database">> => 0,
               <<"password">> => <<"ee">>,
               <<"auto_reconnect">> => true,
               <<"ssl">> => #{<<"enable">> => false},
               <<"cmd">> => <<"HGETALL mqtt_authz:%u">>
              }],
    {ok, _} = emqx_authz:update(replace, Rules),
    Config.

end_per_suite(_Config) ->
    {ok, _} = emqx_authz:update(replace, []),
    emqx_ct_helpers:stop_apps([emqx_authz, emqx_resource]),
    meck:unload(emqx_resource),
    meck:unload(emqx_schema),
    ok.

-define(SOURCE1, [<<"test/%u">>, <<"publish">>]).
-define(SOURCE2, [<<"test/%c">>, <<"publish">>]).
-define(SOURCE3, [<<"#">>, <<"subscribe">>]).

%%------------------------------------------------------------------------------
%% Testcases
%%------------------------------------------------------------------------------

t_authz(_) ->
    ClientInfo = #{clientid => <<"clientid">>,
                   username => <<"username">>,
                   peerhost => {127,0,0,1},
                   zone => default,
                   listener => {tcp, default}
                   },

    meck:expect(emqx_resource, query, fun(_, _) -> {ok, []} end),
    % nomatch
    ?assertEqual(deny,
                 emqx_access_control:authorize(ClientInfo, subscribe, <<"#">>)),
    ?assertEqual(deny,
                 emqx_access_control:authorize(ClientInfo, publish, <<"#">>)),


    meck:expect(emqx_resource, query, fun(_, _) -> {ok, ?SOURCE1 ++ ?SOURCE2} end),
    % nomatch
    ?assertEqual(deny,
        emqx_access_control:authorize(ClientInfo, subscribe, <<"+">>)),
    % nomatch
    ?assertEqual(deny,
        emqx_access_control:authorize(ClientInfo, subscribe, <<"test/username">>)),

    ?assertEqual(allow,
        emqx_access_control:authorize(ClientInfo, publish, <<"test/clientid">>)),
    ?assertEqual(allow,
        emqx_access_control:authorize(ClientInfo, publish, <<"test/clientid">>)),

    meck:expect(emqx_resource, query, fun(_, _) -> {ok, ?SOURCE3} end),

    ?assertEqual(allow,
        emqx_access_control:authorize(ClientInfo, subscribe, <<"#">>)),
    % nomatch
    ?assertEqual(deny,
        emqx_access_control:authorize(ClientInfo, publish, <<"#">>)),
    ok.

