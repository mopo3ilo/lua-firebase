local tools = require 'firebase.tools'

Messaging = {}

function Messaging:new(arg)
  local obj = {}
  local session = tools.check_session_argument(arg)

  function obj:get_session()
    return session
  end

  function obj:request(method, path, data, second)
    local https = require 'ssl.https'
    local ltn12 = require 'ltn12'

    local headers = {}
    if session.ID_TOKEN then
      headers.authorization = string.format('Firebase %s', session.ID_TOKEN)
    end
    if session.ACCESS_TOKEN then
      headers.authorization = string.format('Bearer %s', session.ACCESS_TOKEN)
    end

    local src, source
    if method == 'POST' then
      if not tools.is_table(data) then
        error('Incorrect data argument')
      end

      src = tools.table2json(data)
      source = ltn12.source.string(src)

      headers['content-type']    = 'application/json'
      headers['content-length']  = src:len()
    end

    local body = {}
    local sink = ltn12.sink.table(body)

    local url = string.format('https://fcm.googleapis.com/v1/projects/%s/messages%s', session.PROJECT_ID, path)

    local r, c, h, s = https.request{
      url     = url,
      method  = method,
      sink    = sink,
      headers = headers,
      source  = source
    }
    print(r, c, h, s)
    print(table.concat(body))

    if c == 200 or c == 204 then
      return tools.json2table(table.concat(body))
    end
    if c == 401 or c == 403 then
      if not second then
        if session.auth then
          if session.auth:refresh_session() then
            return obj:request(data, true)
          end
        end
      end
    end
    error(tools.request_error(body, c, s))
  end

  function obj:send(message)
    return obj:request('POST', ':send', message)
  end

  function obj:take(message_id)
    return obj:request('GET', '/' .. tostring(message_id))
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return Messaging
