package = "apicast"
source = { url = '.' }
version = '0.1-0'
dependencies = {
  'lua-resty-http',
  'inspect',
  'router',
  'lua-resty-jwt',
  'lua-resty-url',
  'lua-resty-env',
  'lua-resty-execvp',
}
build = {
   type = "builtin",
   modules = {
   }
}
