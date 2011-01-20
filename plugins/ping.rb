require 'commands'

class Ping <Plugin
  extend Commands
  name :ping
  command!(:ping) { |m| "pong" }
end
