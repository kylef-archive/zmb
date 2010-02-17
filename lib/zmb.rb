require 'socket'

require 'lib/zmb/plugin'
require 'lib/zmb/settings'
require 'lib/zmb/event'

class Zmb
  attr_accessor :plugins, :plugin_sources
  
  def initialize(config_dir)
    @plugin_manager = PluginManager.new
    @settings = Settings.new(config_dir)
    
    @instances = {'core/zmb' => self}
    @sockets = Hash.new
    
    @settings.get('core/zmb', 'plugin_sources', []).each{|source| @plugin_manager.add_plugin_source source}
    @settings.get('core/zmb', 'plugin_instances', []).each{|instance| load instance}
  end
  
  def load(key)
    return true if @instances.has_key?(key)
    
    if p = @settings.get(key, 'plugin') then
      object = @plugin_manager.plugin(p)
      @instances[key] = object.new(self, @settings.setting(key))
      true
    else
      false
    end
  end
  
  def unload(key)
    return false if not @instances.has_key?(key)
    socket_delete @instances.delete(key)
  end
  
  def run
    begin
      while 1
        socket_select(timeout)
      end
    rescue Interrupt
      return
    end
  end
  
  def timeout
    60.0
  end
  
  def socket_add(delegate, socket)
    @sockets[socket] = delegate
  end
  
  def socket_delete(item)
    if @sockets.include?(item) then
      @sockets.select{|sock, delegate| delegate == item}.each{|key, value| @sockets.delete(key)}
    end
    
    if @sockets.has_key?(item) then
      @sockets.delete(item)
    end
  end
  
  def socket_select(timeout)
    result = select(@sockets.keys, nil, nil, timeout)
    
    if result != nil then
      result[0].select{|sock| @sockets.has_key?(sock)}.each do |sock|
        if sock.eof? then
          @sockets[sock].disconnected(self, sock) if @sockets[sock].respond_to?('disconnected')
          socket_delete sock
        else
          @sockets[sock].received(self, sock, sock.gets()) if @sockets[sock].respond_to?('received')
        end
      end
    end
  end
  
  def post(signal, *args)
    results = Array.new
    
    @instances.select{|name, instance| instance.respond_to?(signal)}.each do |name, instance|
      results << instance.send(signal, *args) rescue nil
    end
    
    results
  end
  
  def post!(signal, *args) # This will exclude the plugin manager
    @instances.select{|name, instance| instance.respond_to?(signal) and instance != self}.each do |name, instance|
      instance.send(signal, *args) rescue nil
    end
  end
  
  def event(sender, e)
    post! :pre_event, self, e
    post! :event, self, e
  end
end