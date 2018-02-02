local tools = require 'firebase.tools'

Auth = {}

function Auth:new(arg)
  local obj = {}
  local session = tools.check_session_argument(arg)

  if session.PROJECT_FN and tools.exists_file(session.PROJECT_FN) then
    local t = tools.open_json(session.PROJECT_FN)
    tools.write_in_session(t, session)

    local session_true = true

    if not session.TYPE then
      session_true = false
    elseif session.TYPE == 'legacy' and not(session.ID_TOKEN) then
      session_true = false
    elseif session.TYPE == 'email' and not(session.API_KEY and session.ID_TOKEN and session.REFRESH_TOKEN) then
      session_true = false
    elseif session.TYPE == 'service_account' and not(session.ACCESS_TOKEN and session.CLIENT_EMAIL and session.PRIVATE_KEY) then
      session_true = false
    end

    if not session_true then
      print('Warning! You need to create new session')
    end
  end

  function obj:get_session()
    return session
  end

  function obj:refresh_session()
    -- print(string.format('Refresh %s session', session.TYPE))
    if session.TYPE == 'legacy' then
      return obj:refresh_legacy()
    elseif session.TYPE == 'email' then
      return obj:refresh_email()
    elseif session.TYPE == 'service_account' then
      return obj:refresh_service_account()
    end
    error('You need to create new session')
  end

  function obj:auth_legacy(key)
    if key then
      if not tools.is_string(key) then
        error('Empty key argument')
      end
    elseif not session.ID_TOKEN then
      error('Empty key argument')
    end

    local t = {}
    t.type = 'legacy'
    t.idToken = key or session.ID_TOKEN
    tools.write_in_session(t, session)
    if session.PROJECT_FN then
      return tools.save_json(session.PROJECT_FN, t)
    end
    return t
  end
  obj.refresh_legacy = obj.auth_legacy

  function obj:auth_email(key, email, password, signup)
    for k, v in pairs({ key = key or '', email = email or '', password = password or '' }) do
      if not tools.is_string(v) then
        error(string.format('Empty %s argument', k))
      end
    end

    local json = require 'cjson'
    local https = require 'ssl.https'
    local ltn12 = require 'ltn12'

    local operation = signup and 'signupNewUser' or 'verifyPassword'

    local url = string.format('https://www.googleapis.com/identitytoolkit/v3/relyingparty/%s?key=%s', operation, key)
    local src = json.encode({
      email             = email,
      password          = password,
      returnSecureToken = true
    })
    local headers = {
      ['content-type']    = 'application/json',
      ['content-length']  = tostring(src:len())
    }

    local body = {}
    local sink = ltn12.sink.table(body)
    local source = ltn12.source.string(src)

    local r, c, h, s = https.request{
      url     = url,
      method  = 'POST',
      sink    = sink,
      headers = headers,
      source  = source
    }

    if c == 200 then
      local t = tools.json2table(table.concat(body))
      t.type = 'email'
      t.api_key = key
      tools.write_in_session(t, session)
      if session.PROJECT_FN then
        return tools.save_json(session.PROJECT_FN, t)
      end
      return t
    else
      local t = tools.json2table(table.concat(body))
      local message = t.error and t.error.message

      if c == 400 and message == 'EMAIL_EXISTS' then
        return obj:auth_email(key, email, password, false)
      elseif c == 400 and message == 'EMAIL_NOT_FOUND' then
        return obj:auth_email(key, email, password, true)
      else
        error(tools.request_error(body, c, s))
      end
    end
  end

  function obj:refresh_email()
    if not(tools.is_string(session.API_KEY) and tools.is_string(session.REFRESH_TOKEN)) then
      error('Empty API_KEY and REFRESH_TOKEN arguments')
    end

    local json = require 'cjson'
    local https = require 'ssl.https'
    local ltn12 = require 'ltn12'

    local url = string.format('https://securetoken.googleapis.com/v1/token?key=%s', session.API_KEY)
    local src = tools.build_query({
      grant_type    = 'refresh_token',
      refresh_token = session.REFRESH_TOKEN
    })
    local headers = {
      ['content-type']    = 'application/x-www-form-urlencoded',
      ['content-length']  = tostring(src:len())
    }

    local body = {}
    local sink = ltn12.sink.table(body)
    local source = ltn12.source.string(src)

    local r, c, h, s = https.request{
      url     = url,
      method  = 'POST',
      sink    = sink,
      headers = headers,
      source  = source
    }

    if c == 200 then
      local t = tools.json2table(table.concat(body))
      t.type = 'email'
      t.api_key = session.API_KEY
      tools.write_in_session(t, session)
      if session.PROJECT_FN then
        return tools.save_json(session.PROJECT_FN, t)
      end
      return t
    else
      error(tools.request_error(body, c, s))
    end
  end

  function obj:auth_service_account(path)
    local serv = {}
    if path then
      if not tools.is_string(path) then
        error('Empty path argument')
      end
      if not tools.exists_file(path) then
        error(string.format('Can\'t open file %s', path))
      end
      serv = tools.open_json(path)
    elseif tools.is_string(session.CLIENT_EMAIL) and tools.is_string(session.PRIVATE_KEY) then
      serv.client_email = session.CLIENT_EMAIL
      serv.private_key = session.PRIVATE_KEY
    else
      error('Empty path argument')
    end

    local json    = require 'cjson'
    local https   = require 'ssl.https'
    local ltn12   = require 'ltn12'
    local basexx  = require 'basexx'
    local digest  = require 'openssl.digest'
    local pkey    = require 'openssl.pkey'

    local scopes = {
      'https://www.googleapis.com/auth/firebase',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/devstorage.full_control'
    }

    local header = {
      alg = 'RS256',
      typ = 'JWT'
    }
    header = assert(basexx.to_url64(json.encode(header)))

    local claims = {
      iss = serv.client_email or session.CLIENT_EMAIL,
      scope = table.concat(scopes, ' '),
      aud = 'https://www.googleapis.com/oauth2/v4/token',
      exp = os.time() + 3600,
      iat = os.time()
    }
    claims = assert(basexx.to_url64(json.encode(claims)))

    local jwt = header .. '.' .. claims
    local dig = digest.new('SHA256'):update(jwt)
    local jws = basexx.to_url64(pkey.new(serv.private_key or session.PRIVATE_KEY):sign(dig))
    local jwt = jwt .. '.' .. jws

    local url = 'https://www.googleapis.com/oauth2/v4/token'
    local src = tools.build_query({
      grant_type  = 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion   = jwt
    })
    local headers = {
      ['content-type']    = 'application/x-www-form-urlencoded',
      ['content-length']  = tostring(src:len())
    }

    local body = {}
    local sink = ltn12.sink.table(body)
    local source = ltn12.source.string(src)

    local r, c, h, s = https.request{
      url     = url,
      method  = 'POST',
      sink    = sink,
      headers = headers,
      source  = source
    }

    if c == 200 then
      local t = tools.json2table(table.concat(body))
      t.type = 'service_account'
      t.client_email = serv.client_email
      t.private_key = serv.private_key
      tools.write_in_session(t, session)
      if session.PROJECT_FN then
        return tools.save_json(session.PROJECT_FN, t)
      end
      return t
    else
      error(tools.request_error(body, c, s))
    end
  end
  obj.refresh_service_account = obj.auth_service_account

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return Auth
