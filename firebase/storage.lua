local tools = require 'firebase.tools'

Storage = {}

function Storage:new(arg)
  local obj = {}
  local session = tools.check_session_argument(arg)

  function obj:get_session()
    return session
  end

  function obj:request(method, path, data, second)
    if not tools.is_string(path) then
      error('Incorrect path argument')
    end
    if path:sub(1, 1) ~= '/' then
      error('The path argument must start with "/"')
    end

    local https = require 'ssl.https'
    local ltn12 = require 'ltn12'

    local qry, query
    if tools.is_string(path) then
      qry = tools.split_string(path, '?')
      qry[1] = qry[1] and ('/' .. tools.build_query({ qry[1]:sub(2) }):sub(3)) or ''
      qry[2] = qry[2] and ('?' .. qry[2]) or ''
      query = table.concat(qry)
    else
      query = '/'
    end

    local headers = {}
    if session.ID_TOKEN then
      headers.authorization = string.format('Firebase %s', session.ID_TOKEN)
    end
    if session.ACCESS_TOKEN then
      headers.authorization = string.format('Bearer %s', session.ACCESS_TOKEN)
    end

    local body, file, source, sink = {}
    if method == 'POST' and tools.is_string(data) then
      file = assert(io.open(data, 'r'))
      headers['content-length']  = tostring(tools.file_size(file))
      source = ltn12.source.file(file)
      sink = ltn12.sink.table(body)
    elseif method == 'GET' and tools.is_string(data) then
      file = assert(io.open(data, 'w'))
      sink = ltn12.sink.file(file)
    elseif method == 'PATCH' and tools.is_table(data) then
      local src = tools.table2json(data)
      headers['content-type']    = 'application/json'
      headers['content-length']  = src:len()
      source = ltn12.source.string(src)
      sink = ltn12.sink.table(body)
    else
      sink = ltn12.sink.table(body)
    end

    local url = string.format('https://firebasestorage.googleapis.com/v0/b/%s.appspot.com/o%s', session.PROJECT_ID, query)

    local r, c, h, s = https.request{
      url     = url,
      method  = method,
      sink    = sink,
      headers = headers,
      source  = source
    }

    if c == 200 or c == 204 then
      return tools.json2table(table.concat(body))
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
    error(tools.request_error(body, c, s))
  end

  function obj:list(prefix, max_results)
    local qry = {}
    if tools.is_string(prefix) and prefix:sub(1, 1) == '/' then
      qry.prefix = prefix:sub(2)
    else
      qry.prefix = prefix
    end
    qry.maxResults  = max_results
    local query = '/?' .. tools.build_query(qry)

    local items = obj:request('GET', query)
    if tools.is_table(items) and items.items then
      return items.items
    end
    return items
  end

  function obj:upload(path, filename)
    if not tools.is_string(filename) then
      error('Incorrect filename argument')
    end

    return obj:request('POST', path, filename)
  end

  function obj:download(path, filename)
    if not tools.is_string(filename) then
      error('Incorrect filename argument')
    end

    local qry = {}
    qry.alt   = 'media'
    qry.token = obj:get_token(path)
    local query = path .. '?' .. tools.build_query(qry)

    return obj:request('GET', query, filename)
  end

  function obj:delete(path)
    return obj:request('DELETE', path)
  end

  function obj:set_metadata(path, metadata)
    if not tools.is_table(metadata) then
      error('Incorrect metadata argument')
    end

    return obj:request('PATCH', path, metadata)
  end

  function obj:get_metadata(path)
    return obj:request('GET', path)
  end

  function obj:get_token(path)
    local metadata = obj:request('GET', path)
    local token = metadata.downloadTokens and tools.split_string(metadata.downloadTokens, ',')[1]
    return token
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return Storage
