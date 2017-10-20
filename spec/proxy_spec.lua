local configuration_store = require 'configuration_store'
local Service = require 'configuration.service'

describe('Proxy', function()
  local configuration, proxy

  before_each(function()
    configuration = configuration_store.new()
    proxy = require('proxy').new(configuration)
  end)

  it('has access function', function()
    assert.truthy(proxy.access)
    assert.same('function', type(proxy.access))
  end)

  describe(':call', function()
    before_each(function()
      ngx.var = { backend_endpoint = 'http://localhost:1853' }
      configuration:add(Service.new({ id = 42, hosts = { 'localhost' }}))
    end)

    it('has authorize function after call', function()
      proxy:call('localhost')

      assert.truthy(proxy.authorize)
      assert.same('function', type(proxy.authorize))
    end)

    it('returns access function', function()
      local access = proxy:call('localhost')

      assert.same('function', type(access))
    end)

    it('returns oauth handler when matches oauth route', function()
      local service = configuration:find_by_id(42)
      service.backend_version = 'oauth'
      stub(ngx.req, 'get_method', function() return 'GET' end)
      ngx.var.uri = '/authorize'

      local access, handler = proxy:call('localhost')

      assert.equal(nil, access)
      assert.same('function', type(handler))
    end)
  end)

  describe(':access', function()
    local service
    before_each(function()
      ngx.var = { backend_endpoint = 'http://localhost:1853' }
      service = Service.new({ extract_usage = function() end })
    end)

    it('works with part of the credentials', function()
      service.credentials = { location = 'headers' }
      service.backend_version = 2
      ngx.var.http_app_key = 'key'
      assert.falsy(proxy:access(service))
    end)
  end)

  it('has post_action function', function()
    assert.truthy(proxy.post_action)
    assert.same('function', type(proxy.post_action))
  end)

  it('finds service by host', function()
    local example = { id = 42, hosts = { 'example.com'} }

    configuration:add(example)

    assert.same(example, proxy:find_service('example.com'))
    assert.falsy(proxy:find_service('unknown'))
  end)

  it('does not return old configuration when new one is available', function()
    local foo = { id = '42', hosts = { 'foo.example.com'} }
    local bar = { id = '42', hosts = { 'bar.example.com'} }

    configuration:add(foo, -1) -- expired record
    assert.equal(foo, proxy:find_service('foo.example.com'))

    configuration:add(bar, -1) -- expired record
    assert.equal(bar, proxy:find_service('bar.example.com'))
    assert.falsy(proxy:find_service('foo.example.com'))
  end)

  describe('.get_upstream', function()
    local get_upstream
    before_each(function() get_upstream = proxy.get_upstream end)

    it('sets correct upstream port', function()
      assert.same(443, get_upstream({ api_backend = 'https://example.com' }).port)
      assert.same(80, get_upstream({ api_backend = 'http://example.com' }).port)
      assert.same(8080, get_upstream({ api_backend = 'http://example.com:8080' }).port)
    end)
  end)

  describe('.authorize', function()
    local service = { backend_authentication = { value = 'not_baz' }, backend = { endpoint = 'http://0.0.0.0' } }

    local ngx_backend = require('resty.http_ng.backend.ngx')

    it('takes ttl value if sent', function()
      local ttl = 80
      ngx.var = { cached_key = 'client_id=blah', http_x_3scale_debug='baz', real_url='blah' }

      local response = { status = 200 }
      stub(ngx_backend, 'send', function() return response end)

      stub(proxy, 'cache_handler').returns(true)

      proxy:authorize(service, { foo = 0 }, { client_id = 'blah' }, ttl)

      assert.spy(proxy.cache_handler).was.called_with(proxy.cache, 'client_id=blah:foo=0', response, ttl)
    end)

    it('works with no ttl', function()
      ngx.var = { cached_key = "client_id=blah", http_x_3scale_debug='baz', real_url='blah' }

      local response = { status = 200 }
      stub(ngx_backend, 'send', function() return response end)
      stub(proxy, 'cache_handler').returns(true)

      proxy:authorize(service, { foo = 0 }, { client_id = 'blah' })

      assert.spy(proxy.cache_handler).was.called_with(proxy.cache, 'client_id=blah:foo=0', response, nil)
    end)
  end)
end)
