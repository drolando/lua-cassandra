local Client = require "cassandra.client"
local t_utils = require "cassandra.utils.table"

local FAKE_CLUSTER = {"0.0.0.1", "0.0.0.2", "0.0.0.3"}
--local contact_points_2_0 = {"127.0.0.1"}
local contact_points_2_1 = {"127.0.0.1"}

local function client_factory(opts)
  t_utils.extend_table({print_log_level = "DEBUG"}, opts)
  return Client(opts)
end

describe("Client", function()
  it("should be instanciable", function()
    assert.has_no_errors(function()
      local client = client_factory({contact_points = FAKE_CLUSTER})
      assert.equal(false, client.connected)
    end)
  end)
  describe("#execute()", function()
    describe("#connect() on first #execute()", function()
      local client

      after_each(function()
        local err = client:shutdown()
        assert.falsy(err)
      end)

      it("should return error if no host is available", function()
        client = client_factory({contact_points = FAKE_CLUSTER})
        local _, err = client:execute()
        assert.truthy(err)
        assert.equal("NoHostAvailableError", err.type)
        assert.False(client.connected)
      end)
      it("should connect to a cluster", function()
        client = client_factory({contact_points = contact_points_2_1})
        local _, err = client:execute()
        assert.falsy(err)
        assert.True(client.connected)
      end)
      it("should retrieve cluster information when connecting", function()
        client = client_factory({contact_points = contact_points_2_1})
        local _, err = client:execute()
        assert.falsy(err)
        assert.True(client.connected)

        local hosts = client.hosts
        assert.truthy(hosts["127.0.0.1"])
        assert.truthy(hosts["127.0.0.2"])
        assert.truthy(hosts["127.0.0.3"])

        -- Contact point used should have a socket
        assert.truthy(hosts[contact_points_2_1[1]].connection.socket)

        for _, host in pairs(hosts) do
          assert.truthy(host.address)
          assert.truthy(host.cassandra_version)
          assert.truthy(host.rack)
          assert.truthy(host.datacenter)
          assert.truthy(host.connection.port)
          assert.truthy(host.connection.protocol_version)
        end
      end)
      it("should downgrade the protocol version if the node does not support the most recent one", function()
        pending()
        client = client_factory({contact_points = contact_points_2_0})
        local _, err = client:execute()
        assert.falsy(err)
        assert.True(client.connected)
      end)
    end)
    describe("idk yet", function()
      local client = client_factory({contact_points = contact_points_2_1})

      it("should", function()

      end)
    end)
  end)
end)
