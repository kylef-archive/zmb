require 'socket'

class Event
  attr_accessor :sender, :command, :args, :name, :userhost, :message
  
  def initialize(sender, line)
    puts line
    
    if line[0,1] == ':' then
      line = line[1..-1] # Remove the :
      hostname, command, args = line.split(' ', 3)
      args = "#{hostname} #{args}"
    else
      command, args = line.split(' ', 3)
    end
    
    @sender = sender
    @command = command.downcase
    @args = args
    
    case @command
      when 'privmsg'
        @userhost, @channel, @message = args.split(' ', 3)
        @name, @userhost = @userhost.split('!', 2)
        @message = @message[1..-1]
    end
  end
  
  def private?
    @channel == @sender.nick
  end
  
  def channel
    private? ? @name : @channel
  end
  
  def message?
    @message != nil
  end
  
  def reply(m)
    if message? then
      m = m.split("\n") if not m.respond_to?('each')
      m.each{ |mess| @sender.write "PRIVMSG #{channel} :#{mess}" }
    else
      @sender.write m
    end
  end
end

class IrcConnection
  attr_accessor :host, :port, :channels, :nick, :name, :realname, :password, :throttle
  
  def initialize(sender, settings={})
    @delegate = sender
    
    @host = settings['host'] if settings.has_key?('host')
    @port = Integer(settings['port']) if settings.has_key?('port')
    
    @channels = settings['channels'] if settings.has_key?('channels')
    
    @nick = settings['nick'] if settings.has_key?('nick')
    @name = settings['name'] if settings.has_key?('name')
    @realname = settings['realname'] if settings.has_key?('realname')
    @password = settings['password'] if settings.has_key?('password')
    
    @throttle = 10
    @throttle = settings['throttle'] if settings.has_key?('throttle')
    
    connect
  end
  
  def to_json(*a)
    {
      'host' => @host,
      'port' => @port,
      
      'channels' => @channels,
      
      'nick' => @nick,
      'name' => @name,
      'realname' => @realname,
      'password' => @password,
      
      'throttle' => @throttle,
      'plugin' => 'irc',
    }.to_json(*a)
  end
  
  def self.wizard
    {
      'host' => { 'help' => 'What host would you like to connect to?', 'default' => 'localhost' },
      'port' => { 'help' => 'What port is this server listening on?', 'default' => 6667 },
      'nick' => { 'help' => 'The nickname you wish to use for this irc server.', 'default' => 'zmb' },
      'name' => { 'help' => nil, 'default' => 'zmb' },
      'realname' => { 'help' => nil, 'default' => 'zmb' },
      'password' => { 'help' => 'If the ircd requires a password, enter this here.', 'default' => nil },
    }
  end
  
  def commands
    require 'lib/zmb/commands'
    {
      'join' => PermCommand.new('admin', self, :join_command),
      'part' => PermCommand.new('admin', self, :part_command),
      'raw' => PermCommand.new('admin', self, :raw_command),
      'tell' => PermCommand.new('admin', self, :tell_command, 2),
    }
  end
  
  def nick=(value)
    @nick = value
    write "NICK #{@nick}"
  end
  
  def connected?
    @socket != nil
  end
  
  def connect
    if @host and @port and not connected? then
      @socket = TCPSocket.new(@host, @port)
      @delegate.socket_add(self, @socket)
      perform
    end
  end
  
  def disconnected(sender, socket)
    @socket = nil
    connect
  end
  
  def perform
    write "PASS #{@password}" if @password
    write "NICK #{@nick}" if @nick
    write "USER #{@name} 0 0 :#{@realname}" if @name and @realname
  end
  
  def write(line)
    @socket.write line + "\r\n" if @socket
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
      e = Event.new(self, line)
      
      
      # Catch some events
      case e.command
        when 'ping' then write "PONG #{e.args[1..-1]}"
        when '001' then @channels.each{ |channel| write "JOIN #{channel}" }
        when 'nick' then tmp, @nick = e.args.split(' :', 2)
      end
      
      @delegate.event(self, e)
      line, @buffer = @buffer.split("\r\n", 2)
    end
  end
  
  def join_command(e, channel)
    join channel
    "#{channel} joined"
  end
  
  def part_command(e, channel)
    part channel
    "#{channel} left"
  end
  
  def raw_command(e, line)
    write line
  end
  
  def tell_command(e, to, message)
    message = message.split("\n") if not message.respond_to?('each')
    message.each{ |m| write "PRIVMSG #{to} :#{m}" }
  end
end

Plugin.define do
  name "irc"
  description "irc connections"
  object IrcConnection
end
