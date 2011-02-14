require 'socket'

begin
  require 'json'
rescue LoadError
  require 'rubygems'
  gem 'json'
end

require 'zmb/utils'
require 'zmb/plugin'
require 'zmb/plugins'
require 'zmb/nv'
require 'zmb/settings'
require 'zmb/event'
require 'zmb/timer'

class Zmb
  include ZMB::Plugins
  include ZMB::NV

  attr_accessor :config_dir, :settings_manager
  attr_accessor :plugin_manager, :plugin_sources, :plugins
  attr_accessor :plugin_classes

  def initialize(dir)
    @config_dir = dir
    @running = false

    plugin_dir = File.join(config_dir, 'plugins')
    if not File.exist?(plugin_dir) then
      FileUtils.makedirs(plugin_dir)
    end

    @sockets = Hash.new

    @minimum_timeout = 0.5 # Half a second
    @maximum_timeout = 60.0 # Sixty seconds
    @timers = Array.new

    plugin_dir = File.join(config_dir, 'plugins')
    if not File.exist?(plugin_dir) then
      FileUtils.makedirs(plugin_dir)
    end

    @loaded_plugin_directories = Array.new
    @plugin_classes = Array.new
    @plugins = Array.new

    # Create the DEPRICATED settings_manager
    @settings_manager = Settings.new(config_dir)

    @plugin_sources = nv.key('plugin_sources', [])
    @plugin_sources.each{ |directory| load_plugin_directory(directory) }
    load_plugin_directory(File.join(File.expand_path(File.dirname(File.dirname(__FILE__))), 'plugins'))
    load_plugin_directory(plugin_dir)

    nv.key('plugins', []).each do |plugin_name|
      load_plugin(plugin_name.to_sym)
    end

    if Signal.list.key?("HUP") then
      trap("HUP") { @plugin_manager.refresh_plugin_sources; load "commands"; load "users" }
    end
  end

  def running?
    @running
  end

  # DEPRICATED (See NV)
  def save
    debug("Saving settings")
    @plugins.each{ |p| @settings_manager.save(p.class.name, p) }
    @settings_manager.save('zmb', self)
  end
  
  # Plugins

  def plugins!(plugin_name)
    @plugin_classes.find{ |p| p.name == plugin_name }
  end
  
  def load_plugin_source(source_file)
    begin
      source_data = File.read(source_file)
      source_data =~ /class (\w+) <Plugin/
      source_data += "\n#{$1}"
      p = eval(source_data)
      p.definition_file(File.expand_path(source_file))
      @plugin_classes << p
      debug("Loaded source `#{source_file}` (#{p.name})")
      true
    rescue Exception
      debug("Cannot load source `#{source_file}`", $!)
      false
    end
  end

  def load_plugin_directory(directory)
    $LOAD_PATH << directory
    debug("Loading plugin directory `#{directory}`")
    @loaded_plugin_directories << directory

    definition_files = Dir[
      File.join(File.expand_path(directory), "*.rb"),
      File.join(File.expand_path(directory), "*", "plugin.rb")
    ]

    definition_files.map do |source_file|
      load_plugin_source(source_file)
    end
  end

  def refresh_plugin_directories
    sources = @loaded_plugin_directories
    @plugin_classes = Array.new
    @loaded_plugin_directories = Array.new
    sources.each{ |directory| load_plugin_directory(directory) }
  end

  def load_plugin(plugin_name)
    return true if plugin(plugin_name)

    if definition = plugins!(plugin_name)
      instance = definition.new(self, @settings_manager.setting(plugin_name))
      instance.zmb = self
      post(:plugin_loaded, plugin_name, instance)
      @plugins << instance
      debug("Loaded #{plugin_name}")
      true
    else
      debug("No such plugin #{plugin_name}")
      false
    end
  end

  def unload_plugin(plugin_name, tell=true)
    if p = plugin(plugin_name)
      @plugins.delete(p)
      @settings_manager.save plugin_name, p
      socket_delete p
      p.unloaded if p.respond_to?('unloaded') and tell
      post(:plugin_unloaded, plugin_name, p)
      true
    else
      false
    end
  end

  def reload_plugin!(plugin_name)
    p = plugins!(plugin_name)

    if p
      @plugin_classes.delete(p)
      if load_plugin_source(p.definition_file)
        true
      else
        @plugin_classes << p
        false
      end
    else
      nil
    end
  end

  def reload_plugin(plugin_name)
    if p = plugin(plugin_name)
      sockets = Array.new
      @sockets.each{ |sock,delegate| sockets << sock if delegate == p }
      unload_plugin(plugin_name, false)
      reloaded = reload_plugin!(plugin_name)
      load_plugin(plugin_name)
      p = plugin(plugin_name)
      sockets.each{ |socket| @sockets[socket] = p }
      p.socket = sockets[0] if sockets.size == 1 and p.respond_to?('socket=')
      reloaded
    else
      nil
    end
  end

  def run
    debug('Start runloop')

    @running = true
    post(:zmb_run, self) { return }
    begin
      while @running
        socket_run(timeout)
        timer_run
      end
    rescue Interrupt
      debug('Runloop interrupted')
      save
    end

    debug('End runloop')
    post(:zmb_exit, self)
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
    debug('zmb Forked')
    pid
  end
  
  def fork_command(e=nil)
    run_fork
    "Forked"
  end
  
  def timeout
    _timer_timeout = timer_timeout
    if _timer_timeout > @maximum_timeout
      if @sockets.size < 1 then
        5
      else
        @maximum_timeout
      end
    elsif _timer_timeout > @minimum_timeout
      _timer_timeout
    else
      @minimum_timeout
    end
  end
  
  def socket_add(delegate, socket)
    debug!("(#{delegate}) Socked added")
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
          debug!("(#{@sockets[sock]}) Socket EOF")
        else
          @sockets[sock].received(self, sock, sock.gets()) if @sockets[sock].respond_to?('received')
        end
      end
    end
  end
  
  def timer_timeout # When will the next timer run?
    @plugins.map{ |p| p.timers.map{ |t| t.timeout } }.flatten.sort.fetch(0, @maximum_timeout)
  end
  
  def timer_run
    timers = @plugins.map{ |p| p.timers.select{ |t| t.timeout <= 0.0 } }
    timers.flatten.each do |t|
      t.fire
    end
  end
end
