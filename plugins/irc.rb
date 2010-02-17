require 'socket'

class Event
  attr_accessor :sender, :command, :args, :userhost, :channel, :message
  
  def initialize(sender, line)
    puts line
    if line[0,1] == ':' then
      line = line[1..-1] # Remove the :
      hostname, command, args = line.split(' ', 3)
      args = "#{hostname[1..-1]} #{args}"
    else
      command, args = line.split(' ', 3)
    end
    
    @sender = sender
    @command = command.downcase
    @args = args
    
    case @command
      when 'privmsg'
        @userhost, @channel, @message = args.split(' ', 3)
        @channel = hostname.split('!', 2)[0] if @channel == @sender.nick
        @message = @message[1..-1]
    end
  end
  
  def userhost
    @userhost.split('!', 2)[1]
  end
  
  def message?
    @message != nil
  end
  
  def reply(m)
    if message? then
      @sender.write "PRIVMSG #{@channel} :#{m}"
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
    @port = settings['port'] if settings.has_key?('port')
    
    @channels = settings['channels'] if settings.has_key?('channels')
    
    @nick = settings['nick'] if settings.has_key?('nick')
    @name = settings['name'] if settings.has_key?('name')
    @realname = settings['realname'] if settings.has_key?('realname')
    @password = settings['password'] if settings.has_key?('password')
    
    @throttle = 10
    @throttle = settings['throttle'] if settings.has_key?('throttle')
    
    connect
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
    write "USER #{@name} 0 0 :#{realname}" if @name and @realname
    
    @channels.each{|channel| write "JOIN #{channel}"}
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
      
      if e.command == 'ping' then
        write "PONG #{e.args[1..-1]}"
      end
      
      @delegate.event(self, e)
      line, @buffer = @buffer.split("\r\n", 2)
    end
  end
end

Plugin.define do
  name "irc"
  description "irc connections"
  object IrcConnection
end
