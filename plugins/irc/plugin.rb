require 'irc/connection'

class IrcPlugin <Plugin
  name :irc

  attr_accessor :default_channel_modes

  def initialize(sender, s={})
    super
    @default_channel_modes = ['n', 's', 't']
    @connections = []

    s['networks'] = Hash.new unless s.has_key?('networks')

    s['networks'].each do |network, config|
      server = config['servers'].first
      server['port'] = 6667 unless server.has_key?('port')
      channels = config.has_key?('channels') ? config['channels'] : []
      @connections << IRC::Connection.new(self, network, server['host'], server['port'], server['password'], channels)
    end

    @settings = s
  end

  def settings
    @settings
  end

  def nick
    nv.key('nick', 'zmb')
  end

  def ident
    nv.key('ident', 'zmb')
  end

  def realname
    nv.key('realname', 'ZMB Messenger Bot')
  end

  def zmb_run(core)
    @connections.each{ |c| c.connect }
  end

  def unloaded
    @connections.each{ |c| c.quit }
  end
end
