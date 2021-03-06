require 'socket'

require 'zmb/timer'

class Event
  attr_accessor :delegate, :command, :args, :name, :userhost, :message, :channel, :line
  attr_accessor :nick
  
  def initialize(sender, line)
    @line = line
    
    if line[0,1] == ':' then
      line = line[1..-1] # Remove the :
      hostname, command, args = line.split(' ', 3)
      args = "#{hostname} #{args}"
    else
      command, args = line.split(' ', 3)
    end
    
    @delegate = sender
    @command = command.downcase
    @args = args
    
    case @command
      when 'privmsg'
        @userhost, @channel, @message = args.split(' ', 3)
        @name, @userhost = @userhost.split('!', 2)
        @message = @message[1..-1]
      when 'join'
        @userhost, @channel = args.split(' ', 2)
        @name, @userhost = @userhost.split('!', 2)
        @channel = @channel[1..-1]
      when 'part'
        @userhost, @channel = args.split(' ', 2)
        @name, @userhost = @userhost.split('!', 2)
      when 'kick'
        @userhost, @channel, @name, @message = args.split(' ', 4)
        @nick, @userhost = @userhost.split('!', 2)
        @message = @message[1..-1]
    end
  end
  
  def private?
    @channel == @delegate.nick
  end
  
  def sender
    private? ? @name : @channel
  end
  
  def message?
    @message != nil
  end
  
  def reply(m)
    if message? then
      m = m.split("\n") if not m.respond_to?('each')
      m.each{ |mess| @delegate.message(sender, mess) }
    else
      @delegate.write m
    end
  end
end

class IrcConnection
  attr_accessor :delegate, :host, :port, :channels, :nick, :name, :realname, :password, :throttle
  
  def initialize(sender, s={})
    @delegate = sender
    
    @host = s['host'] if s.has_key?('host')
    begin
      @port = Integer(s['port']) if s.has_key?('port')
    rescue Exception
      @port = 6667
    end
    
    @channels = Array.new
    @channels = s['channels'] if s.has_key?('channels')
    
    @nick = s['nick'] if s.has_key?('nick')
    @name = s['name'] if s.has_key?('name')
    @realname = s['realname'] if s.has_key?('realname')
    @password = s['password'] if s.has_key?('password')
    
    @throttle = 10
    @throttle = s['throttle'] if s.has_key?('throttle')
    
    @delegate.timer_add(Timer.new(self, :connect, 0.1, false)) if sender.running?
  end
  
  def socket=(value)
    @socket = value
  end
  
  def settings
    {
      'host' => @host,
      'port' => @port,
      
      'channels' => @channels,
      
      'nick' => @nick,
      'name' => @name,
      'realname' => @realname,
      'password' => @password,
      
      'throttle' => @throttle,
    }
  end
  
  def self.wizard
    {
      'host' => { 'help' => 'Hostname', 'default' => 'localhost' },
      'port' => { 'help' => 'Port', 'default' => 6667 },
      'nick' => { 'help' => 'Nickname', 'default' => 'zmb' },
      'name' => { 'help' => 'Name', 'default' => 'zmb' },
      'realname' => { 'help' => 'Realname', 'default' => 'Unknown' },
      'password' => { 'help' => 'If the ircd requires a password, enter this here.', 'default' => nil },
    }
  end
  
  def commands
    {
      'join' => [:join_command, 1, {
        :permission => 'admin',
        :help => 'Join a channel',
        :usage => 'channel',
        :example => '#zmb' }],
      'part' => [:part_command, 1, {
        :permission => 'admin',
        :help => 'Leave a channel',
        :usage => 'channel',
        :example => '#zmb' }],
      'cycle' => [:cycle_command, 1, {
        :permission => 'admin',
        :help => 'Part and rejoin a channel',
        :usage => 'channel',
        :example => '#zmb' }],
      'topic' => [:topic_command, 2, {
        :permission => 'admin',
        :help => 'Set the topic in a channel',
        :usage => 'channel topic',
        :example => '#zmb' }],
      'kick' => [:kick_command, 2, {
        :permission => 'admin',
        :help => 'Kick a user from a channel',
        :usage => 'channel user',
        :example => '#zmb zynox' }],
      'channels' => [:channels_command, 1, {
        :permission => 'admin',
        :help => 'List all the channels this bot is in.' }],
      'raw' => [:raw_command, 1, {
        :permission => 'admin',
        :help => 'Send raw IRC commands',
        :usage => 'command',
        :example => 'PRIVMSG #zmb :Hello world!' }],
      'nick' => [:nick_command, 1, {
        :permission => 'admin',
        :help => 'Change the bot\'s nick',
        :usage => 'new-nick',
        :example => 'zmb' }],
      'tell' => [:tell_command, 2, {
        :permission => 'admin',
        :usage => 'location message',
        :example => '#zmb Hello World!' }],
      'reconnect' => [:reconnect_command, 1, {
        :permission => 'admin',
        :help => 'Reconnect to the irc server' }],
    }
  end
  
  def unloaded
    write "Quit :ZMB"
    @socket.close if @socket
  end
  
  def nick=(value)
    write "NICK #{@nick}"
    @nick = value
  end
  
  def connected?
    @socket != nil
  end
  
  def connect
    if @host and @port and not connected? then
      Thread.new do
        @socket = TCPSocket.new(@host, @port)
        @delegate.socket_add(self, @socket)
        perform
      end
    end
  end
  
  def disconnected(sender, socket)
    @socket = nil
    @delegate.timer_add(Timer.new(self, :connect, @throttle))
  end
  
  def perform
    write "PASS #{@password}" if @password
    write "NICK #{@nick}" if @nick
    write "USER #{@name} 0 * :#{@realname}" if @name and @realname
  end
  
  def write(line)
    begin
      @delegate.debug(self, "> #{line}")
      @socket.write line + "\r\n" if @socket
    rescue
      @delegate.debug(self, "Disconnected at write")
      disconnected(self, nil)
    end  
  end
  
  def message(recipient, msg)
    msg.truncate_words(500-recipient.size).each do |m|
      write "PRIVMSG #{recipient} :#{m}"
    end
  end
  
  def join(channel)
    @channels << channel if not @channels.include?(channel)
    write "JOIN #{channel}"
  end
  
  def part(channel)
    @channels.delete(channel) if @channels.include?(channel)
    write "PART #{channel}"
  end
  
  def received(sender, socket, data)
    @buffer = '' if @buffer == nil
    @buffer += data
    line, @buffer = @buffer.split("\r\n", 2)
    @buffer = '' if @buffer == nil
    
    while line != nil do
      @delegate.debug(self, "< #{line}")
      e = Event.new(self, line)
      
      # Catch some events
      case e.command
        when 'ping' then write "PONG #{e.args[1..-1]}"
        when '001' then
          sleep 0.1
          @channels.each{ |channel| write "JOIN #{channel}" }
        when '433' then nick = "#{@nick}_"
      end
      
      @delegate.event(self, e)
      line, @buffer = @buffer.split("\r\n", 2)
    end
  end
  
  def join_command(e, channel)
    e.delegate.join channel
    "#{channel} joined"
  end
  
  def part_command(e, channel)
    e.delegate.part channel
    "left #{channel}"
  end
  
  def cycle_command(e, channel=nil)
    channel = e.channel if not channel
    e.delegate.part channel
    e.delegate.join channel
    "#{channel} cycled"
  end
  
  def topic_command(e, channel, topic=nil)
    if not topic then
      topic = channel
      channel = e.channel
    end
    
    e.delegate.write "TOPIC #{channel} :#{topic}"
  end
  
  def kick_command(e, channel, nick=nil)
    if not nick then
      nick = channel
      channel = e.channel
    end
    
    e.delegate.write "KICK #{channel} #{nick}"
  end
  
  def channels_command(e)
    if e.delegate.channels.size > 0 then
      "Channels: #{e.delegate.channels.join(", ")}"
    else
      "I am not in any channels"
    end
  end
  
  def raw_command(e, line)
    e.delegate.write line
    nil
  end
  
  def nick_command(e, nick)
    e.delegate.write "NICK #{nick}"
    "Nick changed to #{nick}"
  end
  
  def tell_command(e, to, message)
    message = message.split("\n") if not message.respond_to?('each')
    message.each{ |m| e.delegate.message(to, m) }
    nil
  end
  
  def reconnect_command(e, message='Reconnect')
    e.delegate.write "QUIT :#{message}"
  end
  
  def running(sender)
    connect
  end
end

Plugin.define do
  name "irc"
  description "A plugin which allows you to connect to irc servers."
  object IrcConnection
  multi_instances true
end
