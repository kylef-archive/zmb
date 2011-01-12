require 'irc/isupport'

module IRC
  class Delegate
    def irc_registration(connection)
      # Sending a haltcore here will result in not sending the
      # registration lines (NICK, USER or PASS)
    end

    def irc_connected(connection); end
    def irc_disconnected(connection); end
    def irc_raw(connection, line)
      # Sending a haltcore here will mean the irc line
      # will not be parsed.
    end

    def irc_nick(connection, user, old_nick, new_nick); end
    def irc_join(connection, channel, user); end
    def irc_part(connection, channel, user, msg); end
    def irc_kick(connection, channel, user, kicked_user, msg); end
    def irc_topic(connection, channel, user, topic, date); end
    def irc_quit(connection, user, channels); end
    def irc_message(connection, message); end
  end

  class User
    attr_accessor :server
    attr_accessor :nick, :ident, :host
    attr_accessor :realname, :hops, :flags, :connected_server

    def self.prefix(server, val)
      if match = /^(.*)!(.*)@(.*)$/.match(val)
        self.new(server, *(match.to_a[1..-1]))
      end
    end

    def initialize(server, nick, ident=nil, host=nil)
      server.users << self
      @server = server
      @nick = nick
      @ident = ident
      @host = host
    end

    def userhost
      "#{ident}@#{host}"
    end

    def to_s
      "#{nick}!#{ident}@#{host}"
    end

    def message(msg)
      @server.privmsg(@nick, msg)
    end

    def ourself?
      @server.nick == nick
    end

    def channels
      @server.channels.select{ |c| c.has_user?(self) }
    end

    def who
      @server.write("WHO #{nick}")
    end
  end

  class Channel
    attr_accessor :server
    attr_accessor :name
    attr_accessor :key
    attr_accessor :topic, :topic_owner, :topic_date
    attr_accessor :users

    def initialize(server, name)
      @server = server
      @name = name
      @name = "\##{name}" unless server.is_valid_chan?(name)
      @users = Hash.new

      server.channels << self
    end

    def to_s
      @name
    end

    def <<(user)
      if user.class == Hash
        k, v = user.shift
        v = [v] if v.class != Array
        @users[k] = v
      else
        @users[user] = []
      end
    end

    def delete(user)
      @users.delete(user)
    end

    def has_user?(user)
      if user.class == User
        @users.include?(user)
      else
        not @users.find{ |u| u.nick == user}.nil?
      end
    end

    def mode_change(sender, line)
      # +oov spline zynox Derecho
      # +b nick!user@host
    end

    def set_mode(line)
      # +nt
    end

    def message(msg)
      @server.privmsg(@name, msg)
    end

    def part
      @server.write("PART #{name}")
      @server.channels.delete(self)
    end

    def cycle
      part
      @server.write("JOIN #{name}")
    end
  end

  class Message <String
    attr_accessor :connection, :user, :channel, :opts

    def initialize(connection, message)
      super(message)
      @connection = connection
      @opts = Hash.new
    end

    def private?
      @channel.nil?
    end

    def reply(message)
      if @channel
        @channel.message(message)
      elsif @user
        @user.message(message)
      end
    end
  end

  class Connection <PluginForwarder
    attr_accessor :users, :channels
    attr_reader :nick
    attr_accessor :isupport

    def initialize(plugin, network, host, port=6667, nick='zmb', ident='zmb', realname='zmb', channels=[])
      super(plugin)

      @isupport = ISupport.new
      @channels = Array.new
      @users = Array.new

      @socket = nil

      @network = network
      @host = host
      @port = port
      @ident = ident
      @realname = realname
      @auto_join = channels

      @nick = nick # Current nick
      @prefered_nick = nick
    end

    def to_s
      "#{@host}:#{@port}"
    end

    # Attributes

    def nick=(value)
      @nick = value
      write "NICK #{@nick}"
    end

    # Network

    def connected?
      @socket != nil
    end

    def connect
      if @host and @port and not connected?
        @socket = TCPSocket.new(@host, @port)
        @plugin.zmb.socket_add(self, @socket)

        post(:irc_registration, self) { return }

        write "PASS #{@password}" if @password
        write "NICK #{@prefered_nick}" if @prefered_nick
        write "USER #{@ident} 0 * :#{@realname}" if @ident and @realname
      end
    end

    def disconnected(sender, socket)
      @socket = nil if @socket == socket
      post(:irc_disconnected, self) { return }
      add_timer(:connect, 5) # Reconnect
    end

    def write(line)
      begin
        debug("> #{line}")
        @socket.write line + "\r\n" if @socket
      rescue
        debug("Disconnected at write")
        disconnected
      end
    end

    def received(sender, socket, data)
      @buffer = '' if @buffer.nil?
      @buffer += data
      line, @buffer = @buffer.split("\r\n", 2)
      @buffer = '' if @buffer.nil?

      while line != nil do
        debug("< #{line}")
        parse(line)
        line, @buffer = @buffer.split("\r\n", 2)
      end
    end

    def quit(message='zmb')
      write "QUIT #{message}"
      @socket.close
      @socket = nil
    end

    # IRC data

    def nick!(nick)
      @users.find{ |u| u.nick == nick }
    end

    def userhost!(uhost)
      u = @users.find{ |u| u.userhost == uhost }

      if not u
        nick, ident, host = parse_prefix(uhost)
        u = @users.find{ |u| u.nick = nick }
      end

      u
    end

    def prefix!(prefix)
      u = @users.find{ |u| u.to_s == prefix }

      if not u
        nick, ident, host = parse_prefix(prefix)
        u = @users.find{ |u| u.nick == nick }
        if u
          u.ident = ident
          u.host = host
        end
      end

      u
    end

    # Channels

    def is_valid_chan?(chan)
      @isupport[:chantypes].each do |c|
        return true if chan =~ /^#{c}(.+)$/
      end

      false
    end

    def channel!(name)
      @channels.find{ |channel| channel.name == name }
    end

    # Parser

    def parse(line)
      post(:irc_raw, self, line) { return }

      if line =~ /^:(\S+) (\d{3}) ([\w*]+) (.+)$/
        command = Integer($2)
        send("handle_#{command}", $1, $3, $4) if respond_to? "handle_#{command}"
      elsif line =~ /^:(\S+) (\S+) (.+)$/
        command = $2.downcase
        send("handle_#{command}", $1, $3) if respond_to? "handle_#{command}"
      elsif line =~ /^(\S+) (.+)$/ # PING, PONG, ERROR
        command = $1.downcase
        send("handle_#{command}", $2) if respond_to? "handle_#{command}"
      else
        # Bad line
        return
      end
    end

    def parse_prefix(prefix)
      if prefix =~ /^(.*)!(.*)@(.*)$/
        [$1, $2, $3]
      else
        [prefix, nil, nil]
      end
    end

    def clean_trailing(line)
      line.gsub(/^:/, '')
    end

    # Sending
    
    def privmsg(recipient, message)
      message = message.split("\n") if message.respond_to?(:split)
      message.each do |msg|
        write "PRIVMSG #{recipient} :#{msg}"
      end
    end

    # IRC Line handlers

    def handle_nick(uhost, line)
      user = prefix!(uhost)

      if user
        old_nick = user.nick
        user.nick = line
        post(:irc_nick, self, user, old_nick, user.nick)
      end
    end

    def handle_quit(uhost, line)
      user = prefix!(uhost)

      if user
        reason = clean_trailing(line)
        chans = user.channels

        chans.each{ |c| c.delete(user) }
        @users.delete(user)

        post(:irc_quit, self, user, chans)
      end
    end

    def handle_join(prefix, line)
      chan = channel!(clean_trailing(line))
      user = prefix!(prefix)
      user = User.prefix(self, prefix) unless user

      if user
        if not chan and user.ourself?
           chan = Channel.new(self, clean_trailing(line))
        elsif chan
          chan << user
        else
          return
        end

        post(:irc_join, self, chan, user)
      end
    end

    def handle_part(uhost, line)
      channel_name, reason = line.split(' :', 2)
      chan = channel!(channel_name)
      user = prefix!(uhost)

      # Some servers such as InspIRCd add speech marks around a part reason
      reason = $1 if reason =~ /"(.*)"/

      if chan and user
        chan.delete(user)
        @channels.delete(chan) if user.ourself?
        post(:irc_part, self, chan, user, reason)
      end
    end

    def handle_kick(uhost, line)
      if line =~ /^(\S+) (\S+) :(.+)$/
        chan = channel!($1)
        user = prefix!(uhost)
        kicked_user = nick!($2)
        reason = $3

        if chan and user and kicked_user
          chan.delete(kicked_user)
          post(:irc_kick, self, chan, user, kicked_user, reason)
        end
      end
    end

    def handle_topic(uhost, line)
      if line =~ /^(\S+) :(.+)$/
        chan = channel!($1)
        user = prefix!(uhost)

        if chan
          chan.topic = $2
          chan.topic_owner = user
          chan.topic_date = Time.new

          post(:irc_topic, self, chan, user, $2, chan.topic_date)
        end
      end
    end

    def handle_mode(user, mode_line)
      if mode_line =~ /^(\S+) (.+)$/
        chan = channel!($1)
        chan.mode_change(user, $2) if chan
      end
    end

    def handle_privmsg(prefix, line)
      # TODO: detect if its a CTCP, handle_ctcp
      user = prefix!(prefix)
      user = User.prefix(self, prefix) unless user

      if line =~ /^(\S+) :(.+)$/
        message = Message.new(self, $2)
        message.user = user
        message.channel = channel!($1) if $1 != @nick

        post(:irc_message, self, message)
      end
    end

    def handle_ping(line)
      write "PONG #{line}"
    end

    def handle_error(line)
      debug("Error from server: #{clean_trailing(line)}")
    end

    def handle_1(sender, recipient, line)
      # :efnet.xs4all.nl 001 zmb :Welcome to the EFNet Internet Relay Chat Network zmb
      @nick = recipient
      User.new(self, @nick)

      post(:irc_connected, self) { return }
      @auto_join.each{ |c| write("JOIN #{c}") }
    end

    def handle_5(sender, recipient, line)
      @isupport.parse(line)
    end

    def handle_324(sender, recipient, line) # MODE
      if line =~ /^(\S+) (.+)$/
        chan = channel!($1)

        if chan
          chan.set_mode($2)
        end
      end
    end

    def handle_331(sender, recipient, line)
      # :irc.server.com 331 yournick #chan :No topic is set.
      if line =~ /^(\S+) :(.+)$/
        chan = channel!($1)
        chan.topic = '' if chan
      end
    end

    def handle_332(sender, recipient, line)
      # :irc.server.com 332 yournick #chan :Example topic
      if line =~ /^(\S+) :(.+)$/
        chan = channel!($1)
        chan.topic = $2 if chan
      end
    end

    def handle_352(sender, recipient, line) # WHO response
      if match = /^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) :(\d+) (.+)$/.match(line)

        user = prefix!("#{match[5]}!#{match[2]}@#{match[3]}")
        user = nick!(match[5]) unless user

        if user
          user.ident = match[2]
          user.host = match[3]
          user.connected_server = match[4]
          user.flags = match[6].split('')
          user.hops = Integer(match[7])
          user.realname = match[8]
        end
      end
    end

    def handle_353(sender, r, line) # NAMES
      if line =~ /^\S (\S+) :(.+)$/
        chan = channel!($1)

        if chan
          $2.split(' ').each do |u|
            catch(:done) do
              @isupport[:prefix].each do |prefix, mode|
                if match = /^#{mode}(.+)$/.match(u)
                  user = nick!(match[1])
                  user = User.new(self, match[1]) unless user
                  chan << {user => [prefix]}
                  throw :done
                end
              end

              user = nick!(u)
              user = User.new(self, u) unless user
              chan << user
            end
          end
        end
      end
    end

    def handle_366(sender, r, line) # End of names list
      # if we are th only one in there, then lets set some modes
      if line =~ /^(\S+) :(.+)^/
        chan = channel!($1)

        if chan
          if chan.users.count() == 1 # We are the only person in the channel
            # TODO: Set the modes
            # SET @plugin.default_channel_modes()
          end
        end
      end
    end

    def handle_433(sender, recipient, line)
      if line =~ /^(\S+) :Nickname is already in use(\.?)$/
        # nick ($1) is already in use.
        @nick = "#{$1}_"
        write "NICK #{$1}_"
      end
    end
  end

  class Network
    def initialize(plugin, name, servers=[], channels=[])

    end
  end
end
