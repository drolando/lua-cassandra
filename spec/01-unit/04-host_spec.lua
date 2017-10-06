local cassandra = require "cassandra"
local cql = require "cassandra.cql"
local deque = require "util.deque"

describe("_Host", function()
  describe("new", function()
    it("sets stream_ids to the right length", function()
      local host_v2, err = cassandra.new({protocol_version = 2})
      assert.is_nil(err)
      assert.are.equal(2^7-1, deque.length(host_v2.stream_ids))

      local host_v2, err = cassandra.new({protocol_version = 3})
      assert.is_nil(err)
      assert.are.equal(2^15-1, deque.length(host_v2.stream_ids))
    end)
  end)

  describe("send", function()

    local function mock_request()
      local r = cql.requests.startup.new()
      return mock(r)
    end

    local function mock_host()
      local host, err = cassandra.new()
      assert.is_nil(err)
      stub(host.sock, "send")
      stub(host.sock, "receive")
      return host
    end

    it("sets stream_id without overriding existing opts", function()
      local req = mock_request()
      local host = mock_host()
      req.opts = {custom = "option"}

      local _, err = host:send(req)
      assert.is_nil(err)
      assert.are.same({custom = "option", stream_id = 1}, req.opts)
    end)

    it("sets stream_id if there are no existing opts", function()
      local req = mock_request()
      local host = mock_host()

      local _, err = host:send(req)
      assert.is_nil(err)
      assert.are.same({stream_id = 1}, req.opts)
    end)

    it("doesn't crash if there are no stream_ids left", function()
      local req = mock_request()
      local host = mock_host()
      host.stream_ids["last"] = host.stream_ids["first"] - 1

      local _, err = host:send(req)
      assert.is_nil(err)
      assert.is_nil(req.opts)
    end)

    it("puts stream_id back if send fails", function()
      local req = mock_request()
      local host = mock_host()
      host.sock.send = function() return nil, "send failure" end

      local _, err = host:send(req)
      assert.are.equal("send failure", err)
      assert.are.equal(1, deque.popright(host.stream_ids))
    end)

    it("puts stream_id back if receive fails", function()
      local req = mock_request()
      local host = mock_host()
      host.sock.send = function() return true, nil end
      host.sock.receive = function() return nil, "receive failure" end

      local _, err = host:send(req)
      assert.are.equal("receive failure", err)
      assert.are.equal(1, deque.popright(host.stream_ids))
    end)

    it("retries if response stream_id doesn't match", function()
      local req = mock_request()
      local host = mock_host()
      host.sock.send = function() return true, nil end
      host.sock.receive = function() return "foobar", nil end
      local stream_id = 4
      local read_header_count = 0

      cql.frame_reader = {
        version = function(_) return 3 end,
        read_header = function(_)
          read_header_count = read_header_count + 1
          stream_id = stream_id - 1
          return {stream_id = stream_id, body_length = 0}
        end,
        read_body = function(_, _) return "body" end
      }

      local res, err = host:send(req)
      assert.is_nil(err)
      -- The first 2 times the stream_id doesn't match (3 & 2)
      -- The third time is 1 so the function should exit correctly
      assert.are.equal(3, read_header_count)
      -- The stream_id should be back in the deque
      assert.are.equal(1, deque.popright(host.stream_ids))
      assert.are.equal("body", res)
    end)
  end)
end)