require 'socket'

begin
  require 'json'
rescue LoadError
  require 'rubygems'
  gem 'json'
end

require 'zmb/plugin'
require 'zmb/settings'
require 'zmb/event'
require 'zmb/commands'
require 'zmb/timer'

class Zmb
  attr_accessor :instances, :plugin_manager, :settings
  
  def initialize(config_dir)
    @plugin_manager = PluginManager.new
    @settings = Settings.new(config_dir)
    
    @instances = {'core/zmb' => self}
    @sockets = Hash.new
    
    @minimum_timeout = 0.5 # Half a second
    @maximum_timeout = 60.0 # Sixty seconds
    @timers = Array.new
    timer_add(Timer.new(self, :save, 120.0, true)) # Save every 2 minutes
    
    @settings.get('core/zmb', 'plugin_sources', []).each{|source| @plugin_manager.add_plugin_source source}
    @settings.get('core/zmb', 'plugin_instances', []).each{|instance| load instance}
    
    @running = false
  end
  
  def running?
    @running
  end
  
  def to_json(*a)
    {
      'plugin_sources' => @plugin_manager.plugin_sources,
      'plugin_instances' => @instances.keys,
    }.to_json(*a)
  end
  
  def save
    @instances.each{ |k,v| @settings.save(k, v) }
  end
  
  def load(key)
    return true if @instances.has_key?(key)
    
    if p = @settings.get(key, 'plugin') then
      object = @plugin_manager.plugin(p)
      return false if not object
      @instances[key] = object.new(self, @settings.setting(key))
      post! :plugin_loaded, key, @instances[key]
      true
    else
      false
    end
  end
  
  def unload(key, tell=true)
    return false if not @instances.has_key?(key)
    instance = @instances.delete(key)
    @settings.save key, instance
    socket_delete instance
    timer_delete instance
    instance.unloaded if instance.respond_to?('unloaded') and tell
    post! :plugin_unloaded, key, instance
  end
  
  def run
    post! :running, self
    
    @running = true
    begin
      while @running
        socket_run(timeout)
        timer_run
      end
    rescue Interrupt
      return
    end
  end
  
  def timeout
    if timer_timeout > @maximum_timeout
      @maximum_timeout
    elsif timer_timeout > @minimum_timeout
      timer_timeout
    else
      @minimum_timeout
    end
  end
  
  def socket_add(delegate, socket)
    @sockets[socket] = delegate
  end
  
  def socket_delete(item)
    if @sockets.has_value?(item) then
      @sockets.select{ |sock, delegate| delegate == item }.each{ |sock, delegate| @sockets.delete(sock) }
    end
    
    if @sockets.has_key?(item) then
      @sockets.delete(item)
    end
  end
  
  def socket_run(timeout)
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
  
  def timer_add(timer)
    @timers << timer
  end
  
  def timer_delete(search)
    @timers.each{ |timer| @timers.delete(timer) if timer.delegate == search }
    @timers.delete(search)
  end
  
  def timer_timeout # When will the next timer run?
    @timers.map{|timer| timer.timeout}.sort.fetch(0, @maximum_timeout)
  end
  
  def timer_run
    @timers.select{|timer| timer.timeout <= 0.0 and timer.respond_to?("fire") }.each{|timer| timer.fire(self)}
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
  
  def setup(plugin, instance)
    object = @plugin_manager.plugin plugin
    return false if not object
    
    settings = Hash.new
    settings['plugin'] = plugin
    
    if object.respond_to? 'wizard' then
      d = object.wizard
      d.each{ |k,v| settings[k] = v['default'] if v.has_key?('default') and v['default'] }
    end
    
    @settings.save instance, settings
    
    true
  end
  
  def event(sender, e)
    post! :pre_event, self, e
    post! :event, self, e
  end
  
  def commands
    {
      'reload' => PermCommand.new('admin', self, :reload_command),
      'unload' => PermCommand.new('admin', self, :unload_command),
      'load' => PermCommand.new('admin', self, :load_command),
      'save' => PermCommand.new('admin', self, :save_command, 0),
      'loaded' => PermCommand.new('admin', self, :loaded_command, 0),
      'setup' => PermCommand.new('admin', self, :setup_command, 2),
      'set' => PermCommand.new('admin', self, :set_command, 3),
      'get' => PermCommand.new('admin', self, :get_command, 2),
      'clone' => PermCommand.new('admin', self, :clone_command, 2),
      'reset' => PermCommand.new('admin', self, :reset_command),
      'addsource' => PermCommand.new('admin', self, :addsource_command),
    }
  end
  
  def reload_command(e, instance)
    if @instances.has_key?(instance) then
      sockets = Array.new
      @sockets.each{ |sock,delegate| sockets << sock if delegate == @instances[instance] }
      unload(instance, false)
      reloaded = @plugin_manager.reload_plugin(@settings.get(instance, 'plugin'))
      load(instance)
      
      sockets.each{ |socket| @sockets[socket] = @instances[instance] }
      @instances[instance].socket = sockets[0] if sockets.size == 1 and @instances[instance].respond_to?('socket=')
      
      reloaded ? "#{instance} reloaded" : "#{instance} refreshed"
    else
      "No such instance #{instance}"
    end
  end
  
  def unload_command(e, instance)
    if @instances.has_key?(instance) then
      unload(instance)
      "#{instance} unloaded"
    else
      "No such instance #{instance}"
    end
  end
  
  def load_command(e, instance)
    if not @instances.has_key?(instance) then
      load(instance) ? "#{instance} loaded" : "#{instance} did not load correctly"
    else
      "Instance already #{instance}"
    end
  end
  
  def save_command(e)
    save
    'settings saved'
  end
  
  def loaded_command(e)
    @instances.keys.join(', ')
  end
  
  def setup_command(e, plugin, instance)
    if setup(plugin, instance) then
      object = @plugin_manager.plugin plugin
      result = ["Instance saved, please use the set command to override the default configuration for this instance."]
      result += d.map{ |k,v| "#{k} - #{v['help']} (default=#{v['default']})" } if object.respond_to? 'wizard'
      result.join("\n")
    else
      "plugin not found"
    end
  end
  
  def set_command(e, instance, key, value)
    settings = @settings.setting(instance)
    settings[key] = value
    @settings.save(instance, settings)
    "#{key} set to #{value} for #{instance}"
  end
  
  def get_command(e, instance, key)
    if value = @settings.get(instance, key) then
      "#{key} is #{value} for #{instance}"
    else
      "#{instance} or #{instance}/#{key} not found."
    end
  end
  
  def clone_command(e, instance, new_instance)
    if (settings = @settings.setting(instance)) != {} then
      @settings.save(new_instance, settings)
      "The settings for #{instance} were copied to #{new_instance}"
    else
      "No settings for #{instance}"
    end
  end
  
  def reset_command(e, instance)
    @settings.save(instance, {})
    "Settings for #{instance} have been deleted."
  end
  
  def addsource_command(e, source)
    @plugin_manager.add_plugin_source source
    "#{source} added to plugin manager"
  end
end
