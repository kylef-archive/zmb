require 'socket'

require 'lib/zmb/timer'

class Event
  attr_accessor :delegate, :command, :args, :name, :userhost, :message
  
  def initialize(sender, line)
    puts line
    
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
  attr_accessor :host, :port, :channels, :nick, :name, :realname, :password, :throttle
  
  def initialize(sender, settings={})
    @delegate = sender
    
    @host = settings['host'] if settings.has_key?('host')
    begin
      @port = Integer(settings['port']) if settings.has_key?('port')
    rescue Exception
      @port = 6667
    end
    
    @channels = Array.new
    @channels = settings['channels'] if settings.has_key?('channels')
    
    @nick = settings['nick'] if settings.has_key?('nick')
    @name = settings['name'] if settings.has_key?('name')
    @realname = settings['realname'] if settings.has_key?('realname')
    @password = settings['password'] if settings.has_key?('password')
    
    @throttle = 10
    @throttle = settings['throttle'] if settings.has_key?('throttle')
    
    sender.timer_add(Timer.new(self, :connect, 0.1, false)) if sender.running?
  end
  
  def socket=(value)
    @socket = value
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
      'host' => { 'help' => 'Hostname', 'default' => 'localhost' },
      'port' => { 'help' => 'Port', 'default' => 6667 },
      'nick' => { 'help' => 'Nickname', 'default' => 'zmb' },
      'name' => { 'help' => 'Name', 'default' => 'zmb' },
      'realname' => { 'help' => 'Realname', 'default' => 'zmb' },
      'password' => { 'help' => 'If the ircd requires a password, enter this here.', 'default' => nil },
    }
  end
  
  def commands
    require 'zmb/commands'
    {
      'join' => PermCommand.new('admin', self, :join_command),
      'part' => PermCommand.new('admin', self, :part_command),
      'raw' => PermCommand.new('admin', self, :raw_command),
      'tell' => PermCommand.new('admin', self, :tell_command, 2),
    }
  end
  
  def unloaded
    write "Quit :ZMB"
    @socket.close if @socket
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
      Thread.new do
        @socket = TCPSocket.new(@host, @port)
        @delegate.socket_add(self, @socket)
        perform
      end
    end
  end
  
  def disconnected(sender, socket)
    @socket = nil
    sender.timer_add(Timer.new(self, :connect, @throttle))
  end
  
  def perform
    write "PASS #{@password}" if @password
    write "NICK #{@nick}" if @nick
    write "USER #{@name} 0 0 :#{@realname}" if @name and @realname
  end
  
  def write(line)
    @socket.write line + "\r\n" if @socket
  end
  
  def message(recipient, msg)
    write "PRIVMSG #{recipient} :#{msg}"
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
        when '433' then
          @nick="#{@nick}_"
          write "NICK #{@nick}"
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
    "left #{channel}"
  end
  
  def raw_command(e, line)
    write line
    nil
  end
  
  def tell_command(e, to, message)
    msg = msg.split("\n") if not msg.respond_to?('each')
    msg.each{ |m| message(to, m) }
    nil
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
