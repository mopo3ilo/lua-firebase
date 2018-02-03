package = "lua-firebase"
version = "dev-2"

source = {
  url = "git://github.com/mopo3ilo/lua-firebase",
}

description = {
  summary = "A Firebase modules in Lua",
  homepage = "https://github.com/mopo3ilo/lua-firebase",
  maintainer = "Олег Морозов <mopo3ilo@gmail.com>",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "basexx",
  "lua-cjson",
  "luaossl",
  "luasec",
  "luasocket",
  "net-url"
}

build = {
  type = "builtin",
  modules = {
    ["firebase"] = "firebase.lua",
    ["firebase.tools"] = "firebase/tools.lua",
    ["firebase.auth"] = "firebase/auth.lua",
    ["firebase.database"] = "firebase/database.lua",
    ["firebase.storage"] = "firebase/storage.lua",
    ["firebase.messaging"] = "firebase/messaging.lua"
  }
}