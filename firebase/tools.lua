local json  = require 'cjson'

tools = {}

function tools.build_query(qry)
  if tools.is_table(qry) then
    local url = require('socket.url')
    local str = ''
    for k, v in pairs(qry) do
      str = str .. '&' .. url.escape(k) .. '=' .. url.escape(v)
    end
    str = str:sub(2)
    return str
  end
  return ''
end

function tools.split_string(str, sep)
  local t = {}
  if not tools.is_string(str) then
    return t
  end
  for v in string.gmatch(str, string.format('[^%s]+' ,sep)) do
    table.insert(t, v)
  end
  return t
end

function tools.sleep(sec)
  local socket = require 'socket'
  socket.sleep(sec)
  return true
end

function tools.file_size(file)
  local current = file:seek()      -- get current position
  local size = file:seek('end')    -- get file size
  file:seek('set', current)        -- restore position
  return size
end

function tools.check_session_argument(arg)
  local session = {}
  if tools.is_string(arg) then
    session.PROJECT_ID    = arg
    session.PROJECT_FN    = arg .. '-session.json'
  elseif tools.is_table(arg) then
    session = arg
    if not session.PROJECT_ID then
      error('Empty PROJECT_ID argument')
    end
    if not session.PROJECT_FN then
      error('Empty PROJECT_FN argument')
    end
  else
    error('Empty session argument')
  end
  return session
end

function tools.write_in_session(t, session)
  session.TYPE          = t.type
  session.TOKEN_TYPE    = t.token_type
  if session.TYPE == 'service_account' then
    session.ACCESS_TOKEN  = t.access_token
    session.CLIENT_EMAIL  = t.client_email
    session.PRIVATE_KEY   = t.private_key
  else
    session.API_KEY       = t.api_key
    session.ID_TOKEN      = t.idToken or t.id_token
    session.REFRESH_TOKEN = t.refreshToken or t.refresh_token
  end
  return true
end

function tools.exists_file(path)
  local file = io.open(path, 'r')
  if file then
    file:close()
    return true
  else
    return false
  end
end

function tools.open_file(path)
  local file = assert(io.open(path, 'r'))
  local data = file:read('*all')
  file:close()
  return data
end

function tools.save_file(path, data)
  local file = assert(io.open(path, 'w'))
  file:write(data)
  file:close()
  return true
end

function tools.open_json(path)
  return assert(json.decode(tools.open_file(path)))
end

function tools.save_json(path, data)
  return tools.save_file(path, assert(json.encode(data)))
end

function tools.table2json(tbl)
  if tools.is_table(tbl) then
    return assert(json.encode(tbl))
  end
  return '{}'
end

function tools.json2table(str)
  if tools.is_string(str) then
    return assert(json.decode(str))
  end
  return {}
end

function tools.table_clear(tbl)
  if tools.is_table(tbl) then
    for k, v in pairs(tbl) do
      tbl[k] = nil
    end
  end
  return true
end

function tools.is_string(str)
  return str and type(str) == 'string' and str:len() > 0 and true or false
end

function tools.is_table(tbl)
  return tbl and type(tbl) == 'table' and next(tbl) and true or false
end

function tools.body2b(body)
  return next(body) and tools.json2table(table.concat(body)) or {}
end

function tools.request_error(body, code, status)
  local e = {}
  if body.error then
    e.code = body.error.code
    e.message = body.error.message
  else
    local b = tools.body2b(body)
    if b.error then
      e.code = b.error.code
      e.message = b.error.message
    end
  end
  return e.message and (tostring(e.code or code) .. ' ' .. e.message) or status or code
end

function tools.request(method, url, src, silent)
  local https = require 'ssl.https'
  local ltn12 = require 'ltn12'

  local body, headers, source = {}

  if tools.is_table(src) then
    source = json.encode(src)
  end

  if method ~= 'GET' and source then
    headers = {
      ['content-type']    = 'application/json',
      ['content-length']  = tostring(source:len())
    }
  end

  local source = ltn12.source.string(source)
  local sink = ltn12.sink.table(body)

  local r, c, h, s = https.request{
    url     = url,
    method  = method,
    sink    = sink,
    headers = headers,
    source  = source
  }

  if silent then
    local b = tools.body2b(body)
    return r, c, h, s, b
  else
    if c == 200 then
      return tools.json2table(table.concat(body))
    end
    error(tools.request_error(body, c, s))
  end
end

return tools
