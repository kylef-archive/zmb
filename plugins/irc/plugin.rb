require 'irc/connection'

class IrcPlugin <Plugin
  name :irc

  attr_accessor :default_channel_modes

  def initialize(sender, s={})
    super
    @default_channel_modes = ['n', 's', 't']
    @connections = []

    s['nick'] = 'zmb' unless s.has_key?('nick')
    s['ident'] = 'zmb' unless s.has_key?('ident')
    s['realname'] = 'ZMB Bot' unless s.has_key?('realname')
    s['networks'] = Hash.new unless s.has_key?('networks')

    s['networks'].each do |network, config|
      server = config['servers'].first
      server['port'] = 6667 unless server.has_key?('port')
      nick = config.has_key?('nick') ? config['nick'] : s['nick']
      ident = config.has_key?('ident') ? config['ident'] : s['ident']
      realname = config.has_key?('realname') ? config['realname'] : s['realname']
      channels = config.has_key?('channels') ? config['channels'] : []
      @connections << IRC::Connection.new(self, network, server['host'], server['port'], nick, ident, realname, channels)
    end

    @settings = s
  end

  def settings
    @settings
  end

  def zmb_run(core)
    @connections.each{ |c| c.connect }
  end

  def unloaded
    @connections.each{ |c| c.quit }
  end
end
