# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2 + 5);

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: matched with j
--- config
    location /re {
        content_by_lua '
            local m = ngx.re.match("hello, 1234", "([0-9]+)", "j")
            if m then
                ngx.say(m[0])
            else
                ngx.say("not matched!")
            end
        ';
    }
--- request
    GET /re
--- response_body
1234
--- error_log eval
$Test::Nginx::Util::PcreVersion == 2 ?
"pcre2 JIT compiled successfully\n"
:
"pcre JIT compiling result: 1\n"



=== TEST 2: not matched with j
--- config
    location /re {
        content_by_lua '
            local m = ngx.re.match("hello, world", "([0-9]+)", "j")
            if m then
                ngx.say(m[0])
            else
                ngx.say("not matched!")
            end
        ';
    }
--- request
    GET /re
--- response_body
not matched!
--- error_log eval
$Test::Nginx::Util::PcreVersion == 2 ?
"pcre2 JIT compiled successfully\n"
:
"pcre JIT compiling result: 1\n"



=== TEST 3: matched with jo
--- config
    location /re {
        content_by_lua '
            local m = ngx.re.match("hello, 1234", "([0-9]+)", "jo")
            if m then
                ngx.say(m[0])
            else
                ngx.say("not matched!")
            end
        ';
    }
--- request
    GET /re
--- response_body
1234

--- grep_error_log eval
$Test::Nginx::Util::PcreVersion == 2 ?
"pcre2 JIT compiled successfully"
:
"pcre JIT compiling result: 1"

--- grep_error_log_out eval
$Test::Nginx::Util::PcreVersion == 2 ?
["pcre2 JIT compiled successfully\n", ""]
:
["pcre JIT compiling result: 1\n", ""]



=== TEST 4: not matched with jo
--- config
    location /re {
        content_by_lua '
            local m = ngx.re.match("hello, world", "([0-9]+)", "jo")
            if m then
                ngx.say(m[0])
            else
                ngx.say("not matched!")
            end
        ';
    }
--- request
    GET /re
--- response_body
not matched!

--- grep_error_log eval
$Test::Nginx::Util::PcreVersion == 2 ?
"pcre2 JIT compiled successfully"
:
"pcre JIT compiling result: 1"

--- grep_error_log_out eval
$Test::Nginx::Util::PcreVersion == 2 ?
["pcre2 JIT compiled successfully\n", ""]
:
["pcre JIT compiling result: 1\n", ""]



=== TEST 5: bad pattern
--- config
    location /re {
        content_by_lua '
            local m, err = ngx.re.match("hello\\nworld", "(abc", "j")
            if m then
                ngx.say(m[0])

            else
                if err then
                    ngx.say("error: ", err)

                else
                    ngx.say("not matched: ", m)
                end
            end
        ';
    }
--- request
    GET /re
--- response_body eval
$Test::Nginx::Util::PcreVersion == 2 ?
"error: pcre2_compile() failed: missing closing parenthesis in \"(abc\"\n"
:
"error: pcre_compile() failed: missing ) in \"(abc\"\n"
--- no_error_log
[error]



=== TEST 6: just hit match limit
--- http_config
    lua_regex_match_limit 2940;
--- config
    location /re {
        content_by_lua_file html/a.lua;
    }

--- user_files
>>> a.lua
local re = [==[(?i:([\s'\"`´’‘\(\)]*)?([\d\w]+)([\s'\"`´’‘\(\)]*)?(?:=|<=>|r?like|sounds\s+like|regexp)([\s'\"`´’‘\(\)]*)?\2|([\s'\"`´’‘\(\)]*)?([\d\w]+)([\s'\"`´’‘\(\)]*)?(?:!=|<=|>=|<>|<|>|\^|is\s+not|not\s+like|not\s+regexp)([\s'\"`´’‘\(\)]*)?(?!\6)([\d\w]+))]==]

local s = string.rep([[ABCDEFG]], 21)

local start = ngx.now()

local res, err = ngx.re.match(s, re, "jo")

--[[
ngx.update_time()
local elapsed = ngx.now() - start
ngx.say(elapsed, " sec elapsed.")
]]

if not res then
    if err then
        ngx.say("error: ", err)
        return
    end
    ngx.say("failed to match")
    return
end

--- request
    GET /re
--- response_body eval
# lua_regex_match_limit uses pcre_extra->match_limit in the PCRE,
# but PCRE2 replaces this with pcre2_set_match_limit interface,
# which has different effects.
$Test::Nginx::Util::PcreVersion == 2 ?
# PCRE2_ERROR_MATCHLIMIT  (-47)
"error: pcre_exec() failed: -47\n"
:
"error: pcre_exec() failed: -8\n"



=== TEST 7: just not hit match limit
--- http_config
    lua_regex_match_limit 2950;
--- config
    location /re {
        content_by_lua_file html/a.lua;
    }

--- user_files
>>> a.lua
local re = [==[(?i:([\s'\"`´’‘\(\)]*)?([\d\w]+)([\s'\"`´’‘\(\)]*)?(?:=|<=>|r?like|sounds\s+like|regexp)([\s'\"`´’‘\(\)]*)?\2|([\s'\"`´’‘\(\)]*)?([\d\w]+)([\s'\"`´’‘\(\)]*)?(?:!=|<=|>=|<>|<|>|\^|is\s+not|not\s+like|not\s+regexp)([\s'\"`´’‘\(\)]*)?(?!\6)([\d\w]+))]==]

local s = string.rep([[ABCDEFG]], 21)

local start = ngx.now()

local res, err = ngx.re.match(s, re, "jo")

--[[
ngx.update_time()
local elapsed = ngx.now() - start
ngx.say(elapsed, " sec elapsed.")
]]

if not res then
    if err then
        ngx.say("error: ", err)
        return
    end
    ngx.say("failed to match")
    return
end

--- request
    GET /re
--- response_body
failed to match
