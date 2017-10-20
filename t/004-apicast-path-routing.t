use lib 't';
use TestAPIcast 'no_plan';

$ENV{APICAST_PATH_ROUTING_ENABLED} = '1';

repeat_each(1); # Can't be 2 as the second run would hit the cache
run_tests();

__DATA__

=== TEST 1: multi service configuration with path based routing
Two services can exist together and are split by their hostname and mapping rules.
--- main_config
env APICAST_PATH_ROUTING_ENABLED;
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
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/one/",
            hosts = { 'same' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-one',
            proxy_rules = {
              { pattern = '/one', http_method = 'GET', metric_system_name = 'one', delta = 1 }
            }
          }
        },
        {
          id = 21,
          backend_version = 2,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/two/",
            hosts = { 'same' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-two',
            proxy_rules = {
              { pattern = '/two', http_method = 'GET', metric_system_name = 'two', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location ~ /api-backend(/.+) {
     echo 'yay, api backend: $1';
  }

  location ~ /test/(.+) {
    proxy_pass $scheme://127.0.0.1:$server_port/$1$is_args$args;
    proxy_set_header Host same;
  }

  location = /t {
    echo_subrequest GET /test/one -q user_key=one-key;
    echo_subrequest GET /test/two -q app_id=two-id&app_key=two-key;
  }
--- request
GET /t
--- response_body
yay, api backend: /one/
yay, api backend: /two/
--- error_code: 200
--- grep_error_log eval: qr/apicast cache (?:hit|miss|write) key: [^,\s]+/
--- grep_error_log_out
apicast cache miss key: 42:one-key:usage%5Bone%5D=1
apicast cache write key: 42:one-key:usage%5Bone%5D=1
apicast cache miss key: 21:two-id:two-key:usage%5Btwo%5D=2
apicast cache write key: 21:two-id:two-key:usage%5Btwo%5D=2


=== TEST 2: multi service configuration with path based routing defaults to host routing
If none of the services match it goes for the host.
--- main_config
env APICAST_PATH_ROUTING_ENABLED;
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
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/one/",
            hosts = { 'localhost' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-one',
            error_status_no_match = 412,
            proxy_rules = {
              { pattern = '/one', http_method = 'GET', metric_system_name = 'one', delta = 1 }
            }
          }
        },
        {
          id = 21,
          backend_version = 2,
          proxy = {
            api_backend = "http://127.0.0.1:$TEST_NGINX_SERVER_PORT/api-backend/two/",
            hosts = { 'localhost' },
            backend_authentication_type = 'service_token',
            backend_authentication_value = 'service-two',
            proxy_rules = {
              { pattern = '/two', http_method = 'GET', metric_system_name = 'two', delta = 2 }
            }
          }
        }
      }
    })
  }
  lua_shared_dict api_keys 10m;
--- config
  include $TEST_NGINX_APICAST_CONFIG;

  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }

  location ~ /api-backend(/.+) {
     echo 'yay, api backend: $1';
  }
--- request eval
["GET /foo?user_key=1","GET /foo?user_key=2"]
--- no_error_log
--- error_code eval
[ 412, 412 ]
