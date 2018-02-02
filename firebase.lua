local tools = require 'firebase.tools'

Firebase = {}

function Firebase:new(arg)
  local obj = tools.check_session_argument(arg)

  obj.auth      = require('firebase.auth'):new(obj)
  obj.database  = require('firebase.database'):new(obj)
  obj.storage   = require('firebase.storage'):new(obj)
  obj.messaging = require('firebase.messaging'):new(obj)

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return Firebase
