require 'socket'

begin
  require 'json'
rescue LoadError
  require 'rubygems'
  gem 'json'
end

require 'zmb/utils'
require 'zmb/plugin'
require 'zmb/settings'
require 'zmb/event'
require 'zmb/timer'

class Zmb
  attr_accessor :instances, :plugin_manager, :settings_manager, :plugin_sources, :debug
  
  def plugin
    'zmb'
  end
  
  def instance
    'zmb'
  end
  
  def initialize(config_dir)
    @debug = false
    @running = false
    
    @plugin_manager = PluginManager.new(self)
    @settings_manager = Settings.new(config_dir)
    
    @instances = {'zmb' => self}
    @sockets = Hash.new
    
    @minimum_timeout = 0.5 # Half a second
    @maximum_timeout = 60.0 # Sixty seconds
    @timers = Array.new
    timer_add(Timer.new(self, :save, 120.0, true)) # Save every 2 minutes
    
    plugin_dir = File.join(@settings_manager.directory, 'plugins')
    if not File.exist?(plugin_dir) then
      FileUtils.makedirs(plugin_dir)
    end
    
    @plugin_sources = @settings_manager.get('zmb', 'plugin_sources', [])
    @plugin_sources.each{ |source| @plugin_manager.add_plugin_source source }
    @plugin_manager.add_plugin_source File.join(File.expand_path(File.dirname(File.dirname(__FILE__))), 'plugins')
    @plugin_manager.add_plugin_source plugin_dir
    
    @settings_manager.get('zmb', 'plugin_instances', []).each{|instance| load instance}
    @debug = @settings_manager.get('zmb', 'debug', false)
    
    if Signal.list.key?("HUP") then
      trap("HUP") { @plugin_manager.refresh_plugin_sources; load "commands"; load "users" }
    end
  end
  
  def running?
    @running
  end
  
  def settings
    {
      'plugin_sources' => @plugin_sources,
      'plugin_instances' => @instances.keys,
      'debug' => @debug,
    }
  end
  
  def save
    debug(self, "Saving settings")
    @instances.each{ |k,v| @settings_manager.save(k, v) }
  end
  
  def debug(sender, message, exception=nil)
    return unless @debug
    line = Array.new
    
    if sender then
      if sender.respond_to?('instance') then
        line << "(#{sender.instance})"
      elsif sender == self
        line << "(core)"
      elsif sender == plugin_manager
        line << "(plugins)"
      else
        line << "(#{sender})"
      end
    else
      line << "(unknown)"
    end
    
    line << message
    line << exception if exception
    
    puts line.join(' ')
  end
  
  def load(key)
    return true if @instances.has_key?(key)
    
    if p = @settings_manager.get(key, 'plugin') then
      object = @plugin_manager.plugin(p)
      return false if not object
      @instances[key] = object.new(self, @settings_manager.setting(key))
      @instances[key].class.send(:define_method, :plugin) { p }
      @instances[key].class.send(:define_method, :instance) { key }
      post! :plugin_loaded, key, @instances[key]
      true
    else
      false
    end
  end
  
  def unload(key, tell=true)
    return false if not @instances.has_key?(key)
    instance = @instances.delete(key)
    @settings_manager.save key, instance
    socket_delete instance
    timer_delete instance
    instance.unloaded if instance.respond_to?('unloaded') and tell
    post! :plugin_unloaded, key, instance
  end
  
  def run
    debug(self, 'Start runloop')
    post! :running, self
    
    @running = true
    begin
      while @running
        socket_run(timeout)
        timer_run
      end
    rescue Interrupt
      debug(self, 'Runloop interrupted')
      save
    end
  end
  
  def run_fork
    @running = false
    pid = fork {
      STDIN.reopen(File.open('/dev/null','r'))
      STDOUT.reopen(File.open('/dev/null','w'))
      STDERR.reopen(File.open('/dev/null','w'))
      run
    }
    
    Process.detach(pid)
    debug(self, 'zmb Forked')
    pid
  end
  
  def fork_command(e=nil)
    run_fork
    "Forked"
  end
  
  def timeout
    if timer_timeout > @maximum_timeout
      if @sockets.size < 1 then
        5
      else
        @maximum_timeout
      end
    elsif timer_timeout > @minimum_timeout
      timer_timeout
    else
      @minimum_timeout
    end
  end
  
  def socket_add(delegate, socket)
    debug(delegate, "Socked added")
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
          sock.close
          socket_delete sock
          debug(@sockets[sock], "Socket EOF")
        else
          @sockets[sock].received(self, sock, sock.gets()) if @sockets[sock].respond_to?('received')
        end
      end
    end
  end
  
  def timer_add(timer)
    debug(timer.delegate, "Timer added (#{timer.symbol})")
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
    @timers.select{|timer| timer.timeout <= 0.0 and timer.respond_to?("fire") }.each do |timer|
      debug(timer.delegate, "Timer #{timer.symbol} fired")
      timer.fire(self)
    end
  end
  
  def post(signal, *args)
    results = Array.new
    
    @instances.select{|name, instance| instance.respond_to?(signal)}.each do |name, instance|
      begin
        result = instance.send(signal, *args)
        break if result == :halt
        results << result
      rescue Exception
        debug(instance, "Sending signal `#{signal}` failed", $!)
      end
    end
    
    results
  end
  
  def post!(signal, *args) # This will exclude the plugin manager
    @instances.select{|name, instance| instance.respond_to?(signal) and instance != self}.each do |name, instance|
      begin
        break if instance.send(signal, *args) == :halt
      rescue Exception
        debug(instance, "Sending signal `#{signal}` failed", $!)
      end
    end
  end
  
  def setup(plugin, instance)
    object = @plugin_manager.plugin plugin
    return false if not object
    
    s = Hash.new
    s['plugin'] = plugin
    
    if object.respond_to? 'wizard' then
      d = object.wizard
      d.each{ |k,v| s[k] = v['default'] if v.has_key?('default') and v['default'] }
    end
    
    @settings_manager.save instance, s
    
    true
  end
  
  def event(sender, e)
    Thread.new do
      post! :pre_event, sender, e
      post! :event, sender, e
    end
  end
  
  def commands
    {
      'reload' => [:reload_command, 1, { :permission => 'admin' }],
      'unload' => [:unload_command, 1, { :permission => 'admin' }],
      'load' => [:load_command, 1, { :permission => 'admin' }],
      'save' => [:save_command, 0, { :permission => 'admin' }],
      'loaded' => [:loaded_command, 0, { :permission => 'admin' }],
      'setup' => [:setup_command, 2, { :permission => 'admin' }],
      'set' => [:set_command, 3, { :permission => 'admin' }],
      'get' => [:get_command, 2, { :permission => 'admin' }],
      'clone' => [:clone_command, 2, { :permission => 'admin' }],
      'reset' => [:reset_command, 1, { :permission => 'admin' }],
      'addsource' => [:addource_command, 1, { :permission => 'admin' }],
      'refresh' => [:refresh_command, 1, { :permission => 'admin' }],
      'quit' => [:quit_command, 0, { :permission => 'admin' }],
      'debug' => [:debug_command, 0, {
        :permission => 'admin',
        :help => 'Toggle debug' }],
      'stdout' => [:stdout_command, {
        :permission => 'admin',
        :usage => '/dev/null' }],
      'fork' => [:fork_command, 0, {
        :permission => 'admin' }],
    }
  end
  
  def reload_command(e, instance)
    if @instances.has_key?(instance) then
      sockets = Array.new
      @sockets.each{ |sock,delegate| sockets << sock if delegate == @instances[instance] }
      unload(instance, false)
      reloaded = @plugin_manager.reload_plugin(@settings_manager.get(instance, 'plugin'))
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
      "Instance already loaded #{instance}"
    end
  end
  
  def save_command(e)
    save
    'settings saved'
  end
  
  def loaded_command(e)
    @instances.keys.join(', ')
  end
  
  def setup_command(e, plugin, instance=nil)
    instance = plugin if not instance
    
    if setup(plugin, instance) then
      object = @plugin_manager.plugin plugin
      result = ["Instance saved, please use the set command to override the default configuration for this instance."]
      result += object.wizard.map{ |k,v| "#{k} - #{v['help']} (default=#{v['default']})" } if object.respond_to? 'wizard'
      result.join("\n")
    else
      "plugin not found"
    end
  end
  
  def set_command(e, instance, key, value)
    settings = @settings_manager.setting(instance)
    settings[key] = value
    @settings_manager.save(instance, settings)
    
    if @instances.has_key?(instance) and @instances[instance].respond_to?('update') then
      @instances[instance].update(key, value)
    end
    
    "#{key} set to #{value} for #{instance}"
  end
  
  def get_command(e, instance, key)
    if value = @settings_manager.get(instance, key) then
      "#{key} is #{value} for #{instance}"
    else
      "#{instance} or #{instance}/#{key} not found."
    end
  end
  
  def clone_command(e, instance, new_instance)
    if (settings = @settings_manager.setting(instance)) != {} then
      @settings_manager.save(new_instance, settings)
      "The settings for #{instance} were copied to #{new_instance}"
    else
      "No settings for #{instance}"
    end
  end
  
  def reset_command(e, instance)
    @settings_manager.save(instance, {})
    "Settings for #{instance} have been deleted."
  end
  
  def addsource_command(e, source)
    @plugin_sources << source
    @plugin_manager.add_plugin_source source
    "#{source} added to plugin manager"
  end
  
  def refresh_command(e)
    @plugin_manager.refresh_plugin_sources
    "Refreshed plugin sources"
  end
  
  def quit_command(e)
    e.reply "Quitting"
    save
    @running = false
    instances.keys.each{ |i| unload(i) }
  end
  
  def debug_command(e)
    @debug = (not @debug)
    
    if @debug then
      "Debugging enabled"
    else
      "Debugging disabled"
    end
  end
  
  def stdout_command(e, out)
    STDOUT.reopen(File.open(out,'w'))
    "STDOUT set to #{out}"
  end
end
