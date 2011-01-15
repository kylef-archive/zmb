require 'commands'

class Sed <Plugin
  extend Commands

  name :sed

  def initialize(sender, settings)
    super
    @messages = Hash.new
  end

  def irc_message(connection, message)
    if @messages.has_key?(message.user)
      if message =~ /^s\/(\S+)\/(\S+)?$/ then
        message.reply("#{message.user.nick} meant #{@messages[message.user].sub($1, $2)}")
      elsif message =~ /^!!(.+)$/ then
        message.replace(@messages[message.user] + $1)
      end
    end

    @messages[message.user] = message
  end
end
