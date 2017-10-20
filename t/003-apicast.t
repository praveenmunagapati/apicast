use lib 't';
use TestAPIcast 'no_plan';

run_tests();

__DATA__

=== TEST 1: authentication credentials missing
The message is configurable as well as the status.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_missing = 'credentials missing!',
            error_status_auth_missing = 401
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_BACKEND_CONFIG;
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /
--- response_body chomp
credentials missing!
--- error_code: 401

=== TEST 2: credentials missing default error
There are defaults defined for the error message, the content-type, and the
status code (401).
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 2,
        }
      }
    })
  }
--- config
include $TEST_NGINX_BACKEND_CONFIG;
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?app_key=42
--- response_headers
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Authentication parameters missing
--- error_code: 401

=== TEST 3: authentication (part of) credentials missing configurable error
The message is configurable as well as the status.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 2,
          proxy = {
            error_auth_missing = 'credentials missing!',
            error_status_auth_missing = 401
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_BACKEND_CONFIG;
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?app_key=42
--- response_body chomp
credentials missing!
--- error_code: 401

=== TEST 4: no mapping rules matched default error
There are defaults defined for the error message, the content-type, and the
status code (404).
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
        }
      }
    })
  }
--- config
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?user_key=value
--- response_body chomp
No Mapping Rule matched
--- response_headers
Content-Type: text/plain; charset=utf-8
no mapping rules!
--- error_code: 404
--- error_log
could not find proxy for request

=== TEST 5: no mapping rules matched configurable error
The message is configurable and status also.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            error_no_match = 'no mapping rules!',
            error_status_no_match = 412
          }
        }
      }
    })
  }
--- config
include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?user_key=value
--- response_body chomp
no mapping rules!
--- error_code: 412
--- error_log
could not find proxy for request

=== TEST 6: authentication credentials invalid default error
There are defaults defined for the error message, the content-type, and the
status code (403).
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
      deny all;
  }

  location /api-backend/ {
     echo 'yay';
  }
--- request
GET /?user_key=value
--- response_headers
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Authentication failed
--- error_code: 403

=== TEST 7: authentication credentials invalid configurable error
The message is configurable and default status is 403.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_auth_failed = 'credentials invalid!',
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            error_status_auth_failed = 402,
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
      deny all;
  }

  location /api-backend/ {
     echo 'yay';
  }
--- request
GET /?user_key=value
--- response_body chomp
credentials invalid!
--- error_code: 402

=== TEST 8: api backend gets the request
It asks backend and then forwards the request to the api.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;

  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'token-value',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      local args = ngx.var.args
      if args == expected then
        ngx.exit(200)
      else
        ngx.log(ngx.ERR, expected, ' did not match: ', args)
        ngx.exit(403)
      end
    }
  }

  location /api-backend/ {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend: 127.0.0.1
--- error_code: 200
--- error_log
apicast cache miss key: 42:value:usage%5Bhits%5D=2
--- no_error_log
[error]

=== TEST 9: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            error_no_match = 'no mapping rules matched!',
            error_status_no_match = 412,
            proxy_rules = {
              { pattern = '/foo?bar=baz',  querystring_parameters = { bar = 'baz' },
                http_method = 'GET', metric_system_name = 'bar', delta = 1 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar=foo&user_key=somekey
--- response_body chomp
no mapping rules matched!
--- error_code: 412

=== TEST 10: mapping rule with fixed value is mandatory
When mapping rule has a parameter with fixed value it has to be matched.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar=baz',  querystring_parameters = { bar = 'baz' },
                http_method = 'GET', metric_system_name = 'bar', delta = 1 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar=baz&user_key=somekey
--- response_body
api response
--- response_headers
X-3scale-matched-rules: /foo?bar=baz
--- error_code: 200
--- no_error_log
[error]

=== TEST 11: mapping rule with variable value is required to be sent
When mapping rule has a parameter with variable value it has to exist.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/',
            proxy_rules = {
              { pattern = '/foo?bar={baz}',  querystring_parameters = { bar = '{baz}' },
                http_method = 'GET', metric_system_name = 'bar', delta = 3 }
            }
          }
        },
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- request
GET /foo?bar={foo}&user_key=somekey
--- response_body
api response
--- error_code: 200
--- response_headers
X-3scale-matched-rules: /foo?bar={baz}
X-3scale-usage: usage%5Bbar%5D=3


=== TEST 12: https api backend works

--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          proxy = {
            api_backend = 'https://127.0.0.1:1953/api/',
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 1m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;
  listen 1953 ssl;

  ssl_certificate ../html/server.crt;
  ssl_certificate_key ../html/server.key;

  location /api/ {
    echo "api response";
  }

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- user_files
>>> server.crt
-----BEGIN CERTIFICATE-----
MIIB0DCCAXegAwIBAgIJAISY+WDXX2w5MAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTYxMjIzMDg1MDExWhcNMjYxMjIxMDg1MDExWjBFMQsw
CQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhkmo
6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1cbx0wVEzbYK5wRb7U
iWhvvvYDltIzsD75vqNQME4wHQYDVR0OBBYEFOBBS7ZF8Km2wGuLNoXFAcj0Tz1D
MB8GA1UdIwQYMBaAFOBBS7ZF8Km2wGuLNoXFAcj0Tz1DMAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDRwAwRAIgZ54vooA5Eb91XmhsIBbp12u7cg1qYXNuSh8zih2g
QWUCIGTHhoBXUzsEbVh302fg7bfRKPCi/mcPfpFICwrmoooh
-----END CERTIFICATE-----
>>> server.key
-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIFCV3VwLEFKz9+yTR5vzonmLPYO/fUvZiMVU1Hb11nN8oAoGCCqGSM49
AwEHoUQDQgAEhkmo6Xp/9W9cGaoGFU7TaBFXOUkZxYbGXQfxyZZucIQPt89+4r1c
bx0wVEzbYK5wRb7UiWhvvvYDltIzsD75vg==
-----END EC PRIVATE KEY-----
--- request
GET /test?user_key=foo
--- no_error_log
[error]
--- response_body
api response
--- error_code: 200

=== TEST 13: print warning on duplicate service hosts
So when booting it can be immediately known that some of them won't work.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location /t {
  content_by_lua_block {
    require('configuration_loader').global({
      services = {
        { id = 1, proxy = { hosts = { 'foo', 'bar' } } },
        { id = 2, proxy = { hosts = { 'foo', 'daz' } } },
        { id = 1, proxy = { hosts = { 'foo', 'fee' } } },
      }
    })
    ngx.say('all ok')
  }
}
--- request
GET /t
--- response_body
all ok
--- log_level: warn
--- error_code: 200
--- grep_error_log eval: qr/host .+? for service .? already defined by service [^,\s]+/
--- grep_error_log_out
host foo for service 2 already defined by service 1

=== TEST 14: print message that service was added to the configuration
Including it's host so it is easy to see that configuration was loaded.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
location /t {
  content_by_lua_block {
    require('configuration_loader').global({
      services = {
        { id = 1, proxy = { hosts = { 'foo', 'bar' } } },
        { id = 2, proxy = { hosts = { 'baz', 'daz' } } },
      }
    })
    ngx.say('all ok')
  }
}
--- request
GET /t
--- response_body
all ok
--- log_level: info
--- error_code: 200
--- error_log
added service 1 configuration with hosts: foo, bar
added service 2 configuration with hosts: baz, daz

=== TEST 15: return headers with debugging info
When X-3scale-Debug header has value of the backend authentication.
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'service-token',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/",
            backend = {
                endpoint = 'http://127.0.0.1:$TEST_NGINX_SERVER_PORT'
            },
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
       },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;
  include $TEST_NGINX_BACKEND_CONFIG;

  location /api/ {
    echo "all ok";
  }
--- request
GET /t?user_key=val
--- more_headers
X-3scale-Debug: service-token
--- response_body
all ok
--- error_code: 200
--- no_error_log
[error]
--- response_headers
X-3scale-matched-rules: /
X-3scale-usage: usage%5Bhits%5D=2

=== TEST 16: uses endpoint host as Host header
when connecting to the backend
--- main_config
env RESOLVER=127.0.0.1:1953;
--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  lua_shared_dict api_keys 1m;
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          id = 42,
          backend_version = 1,
          backend_authentication_type = 'service_token',
          backend_authentication_value = 'service-token',
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api/",
            backend = {
                endpoint = 'http://localhost.example.com:$TEST_NGINX_SERVER_PORT'
            },
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits', delta = 2 }
            }
          }
       },
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /api/ {
    echo "all ok";
  }

  location /transactions/authrep.xml {
     content_by_lua_block {
       if ngx.var.host == 'localhost.example.com' then
         ngx.exit(200)
       else
         ngx.log(ngx.ERR, 'invalid host: ', ngx.var.host)
         ngx.exit(404)
       end
     }
  }
--- request
GET /t?user_key=val
--- response_body
all ok
--- error_code: 200
--- udp_listen: 1953
--- udp_reply dns
[ "localhost.example.com", "127.0.0.1", 3600 ]
--- no_error_log
[error]

=== TEST 17: invalid service
The message is configurable and default status is 403.
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
--- config
  include $TEST_NGINX_APICAST_CONFIG;
--- request
GET /?user_key=value
--- error_code: 404
--- no_error_log
[error]

=== TEST 18: default limits exceeded error
There are defaults defined for the error message, the content-type, and the
status code (429).
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  include $TEST_NGINX_UPSTREAM_CONFIG;
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 1,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block {
      if ngx.var['http_3scale_options'] == 'rejection_reason_header=1' then
        ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
      end
      ngx.status = 409;
      ngx.exit(ngx.HTTP_OK);
    }
  }

  location /api-backend/ {
     echo 'yay';
  }
--- request
GET /?user_key=value
--- response_headers
Content-Type: text/plain; charset=utf-8
--- response_body chomp
Limits exceeded
--- error_code: 429
--- no_error_log
[error]

=== TEST 19: configurable limits exceeded error
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  include $TEST_NGINX_UPSTREAM_CONFIG;
  init_by_lua_block {
    require('configuration_loader').mock({
      services = {
        {
          backend_version = 1,
          proxy = {
            error_limits_exceeded = 'limits exceeded!',
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/",
            error_status_limits_exceeded = 402,
            proxy_rules = {
              { pattern = '/', http_method = 'GET', metric_system_name = 'hits' }
            }
          }
        }
      }
    })
  }
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block {
      if ngx.var['http_3scale_options'] == 'rejection_reason_header=1' then
        ngx.header['3scale-rejection-reason'] = 'limits_exceeded';
      end
      ngx.status = 409;
      ngx.exit(ngx.HTTP_OK);
    }
  }

  location /api-backend/ {
     echo 'yay';
  }
--- request
GET /?user_key=value
--- response_body chomp
limits exceeded!
--- error_code: 402
--- no_error_log
[error]
