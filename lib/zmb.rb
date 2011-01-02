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
  attr_accessor :settings_manager, :debug
  attr_accessor :plugin_manager, :plugin_sources, :plugins
  
  def initialize(config_dir)
    @debug = false
    @running = false
    
    @plugin_manager = PluginManager.new(self)
    @settings_manager = Settings.new(config_dir)
    
    @plugins = Array.new
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
    
    @settings_manager.get('zmb', 'plugins', []).each do |plugin_name|
      load plugin_name
    end

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
      'plugins' => @plugins.collect{ |p| p.plugin },
      'debug' => @debug,
    }
  end
  
  def save
    debug(self, "Saving settings")
    @plugins.each{ |p| @settings_manager.save(p.plugin, p) }
    @settings_manager.save('zmb', self)
  end
  
  def debug(sender, message, exception=nil)
    return unless @debug
    line = Array.new
    
    if sender then
      if sender == self
        line << "(core)"
      elsif sender.respond_to?('plugin')
        line << "(#{sender.plugin})"
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

  # Plugins

  def plugin(name)
    @plugins.find{ |p| p.plugin == name }
  end
  
  def load(name)
    debug(self, "loading #{name}")

    return true if plugin(name)

    if p = @plugin_manager.plugin(name)
      inst = p.new(self, @settings_manager.setting(name))
      inst.class.send(:define_method, :plugin) { "#{name}" }
      post! :plugin_loaded, name, inst
      @plugins << inst
      true
    else
      false
    end
  end

  def unload(name, tell=true)
    p = plugin(name)

    if p
      @plugins.delete(p)
      @settings_manager.save name, p
      socket_delete p
      timer_delete p
      p.unloaded if p.respond_to?('unloaded') and tell
      post! :plugin_unloaded, name, p
      true
    else
      false
    end
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
    
    @plugins.select{ |p| p.respond_to?(signal) }.each do |p|
      begin
        result = p.send(signal, *args)
        break if result == :halt
        results << result
      rescue Exception
        debug(p, "Sending signal `#{signal}` failed", $!)
      end
    end
    
    results
  end
  
  def post!(signal, *args) # This will exclude the plugin manager
    @plugins.select{ |p| p.respond_to?(signal) and p != self }.each do |p|
      begin
        break if p.send(signal, *args) == :halt
      rescue Exception
        debug(p, "Sending signal `#{signal}` failed", $!)
      end
    end
  end
  
  def setup(plugin_name)
    object = @plugin_manager.plugin(plugin_name)
    return false if not object
    
    s = Hash.new

    if object.respond_to? 'wizard' then
      d = object.wizard
      d.each{ |k,v| s[k] = v['default'] if v.has_key?('default') and v['default'] }
    end
    
    @settings_manager.save(plugin_name, s)
    
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
  
  def reload_command(e, plugin_name)
    if p = plugin(plugin_name)
      sockets = Array.new
      @sockets.each{ |sock,delegate| sockets << sock if delegate == p }
      unload(plugin_name, false)
      reloaded = @plugin_manager.reload_plugin(plugin_name)
      load(plugin_name)
      p = plugin(plugin_name)
      sockets.each{ |socket| @sockets[socket] = p }
      p.socket = sockets[0] if sockets.size == 1 and p.respond_to?('socket=')
      reloaded ? "#{plugin_name} reloaded" : "#{plugin_name} refreshed"
    else
      "No such plugin #{plugin_name}"
    end
  end

  def unload_command(e, plugin_name)
    if plugin(plugin_name)
      unload(plugin_name)
      "#{plugin_name} unloaded"
    else
      "No such plugin #{plugin_name}"
    end
  end

  def load_command(e, plugin_name)
    if plugin(plugin_name)
      "Plugin is already loaded #{plugin_name}"
    else
      load(plugin_name) ? "#{plugin_name} loaded sucsessfully" : "#{plugin_name} failed to load"
    end
  end
  
  def save_command(e)
    save
    'settings saved'
  end
  
  def loaded_command(e)
    @plugins.collect{ |p| p.plugin }.join(', ')
  end
  
  def setup_command(e, plugin_name)
    if setup(plugin) then
      object = @plugin_manager.plugin plugin
      result = ["Plugin saved, please use the set command to override the default configuration for this plugin."]
      result += object.wizard.map{ |k,v| "#{k} - #{v['help']} (default=#{v['default']})" } if object.respond_to? 'wizard'
      result.join("\n")
    else
      "plugin not found"
    end
  end
  
  def set_command(e, plugin_name, key, value)
    settings = @settings_manager.setting(plugin_name)
    settings[key] = value
    @settings_manager.save(plugin_name, settings)
    
    if p = plugin(plugin_name)
      p.update(key, value) if p.respond_to?('update')
    end

    "#{key} set to #{value} for #{plugin_name}"
  end
  
  def get_command(e, plugin_name, key)
    if value = @settings_manager.get(plugin_name, key) then
      "#{key} is #{value} for #{plugin_name}"
    else
      "#{plugin_name} or #{plugin_name}/#{key} not found."
    end
  end

  def reset_command(e, plugin_name)
    @settings_manager.save(plugin_name, {})
    "Settings for #{plugin_name} have been deleted."
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
    @plugins.each{ |p| unload(p.plugin) }
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
