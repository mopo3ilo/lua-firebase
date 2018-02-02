local tools = require 'firebase.tools'

Database = {}

function Database:new(arg)
  local obj = {}
  local session = tools.check_session_argument(arg)

  function obj:get_session()
    return session
  end

  function obj:request(method, path, data, second)
    local qry = {
      auth          = session.ID_TOKEN,
      access_token  = session.ACCESS_TOKEN
    }

    local src = {}

    if tools.is_table(data) then
      for k, v in pairs(data) do
        if method == 'GET' then
          if type(v) == 'string' then
            v = '"' .. v .. '"'
          end
          qry[k] = tostring(v)
        else
          src[k] = v
        end
      end
    end
    
    local query = tools.build_query(qry)
    local url = string.format('https://%s.firebaseio.com%s.json?%s', session.PROJECT_ID, path, query)

    local r, c, h, s, b = tools.request(method, url, src, true)

    if c == 200 or c == 204 then
      return b
    end
    if c == 401 or c == 403 then
      if not second then
        if session.auth then
          if session.auth:refresh_session() then
            return obj:request(method, path, data, true)
          end
        end
      end
    end
    error(tools.request_error(b, c, s))
  end

  function obj:get(path, data)
    return obj:request('GET', path, data)
  end
  obj.read = obj.get

  function obj:put(path, data)
    return obj:request('PUT', path, data)
  end
  obj.write = obj.put

  function obj:post(path, data)
    return obj:request('POST', path, data)
  end
  obj.push = obj.post

  function obj:patch(path, data)
    return obj:request('PATCH', path, data)
  end
  obj.update = obj.patch

  function obj:delete(path)
    return obj:request('DELETE', path)
  end
  obj.remove = obj.delete

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return Database
