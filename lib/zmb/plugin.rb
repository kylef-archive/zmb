class Halt <Exception; end
class HaltCore <Halt; end

class Plugin
  attr_accessor :zmb, :timers

  class << self
    def self.attr_rw(*attrs)
      attrs.each do |attr|
        class_eval %Q{
          def #{attr}(val=nil)
            val.nil? ? @#{attr} : @#{attr} = val
          end
        }
      end
    end

    attr_rw :name, :description, :definition_file
  end

  def halt(*args)
    raise Halt.new(*args)
  end

  def haltcore(*args)
    raise HaltCore.new(*args)
  end

  def initialize(core, s)
    @zmb = core
    @timers = Array.new
  end

  def plugins
    zmb.plugins
  end

  def plugin(symbol)
    plugins.find{ |p| p.class.name == symbol }
  end

  def plugin!(name)
    plugin(name.to_sym)
  end

  def debug(message, exception=nil)
    zmb.debug(self, message, exception) if @zmb
  end

  def post(signal, *args, &block)
    plugins.select{ |p| p.respond_to?(signal) }.each do |p|
      begin
        p.send(signal, *args)
      rescue HaltCore
        block.call if block
        return
      rescue Halt
        return
      rescue
        zmb.debug(p, "Sending signal `#{signal}` failed", $!)
      end
    end
  end

  def directory
    d = File.join(zmb.settings_manager.directory, self.class.name.to_s)
    Dir.mkdir(d) unless File.exists?(d)
    d
  end

  # NV (Non-volatile memory)

  # Get / Save
  def nv(key, value=nil, write=true)
    load_nv if @nv.nil?

    if value.nil?
      @nv[key]
    else
      @nv[key] = value
      save_nv if write
    end
  end

  def nv?(key)
    load_nv if @nv.nil?
    @nv.has_key?(key)
  end

  # Delete
  def nv!(key, write=true)
    load_nv if @nv.nil?
    ret = @nv.delete(key)
    save_nv if write
    ret
  end

  def nv_file # Returns the location of the NV file
    File.join(directory, 'nv.json')
  end

  def load_nv
    if File.exists?(nv_file)
      @nv = JSON.parse(File.read(nv_file))
    else
      @nv = Hash.new
    end
  end

  def save_nv
    @nv = Hash.new unless @nv

    File.open(nv_file, 'w') do |f|
      f.write(@nv.to_json)
    end
  end

  # Timers

  def add_timer(symbol, interval, repeat=false, data=nil)
    t = Timer.new(self, symbol, interval, repeat, data)
    @timers << t
    t
  end

  def del_timer(t)
    @timers.delete(t)
  end
end

class PluginForwarder
  # This class is useful for use in other classes a plugin might have.
  # It allows you to use post, debug, halt, etc inside other
  # non-plugin classes. It just requires @plugin to be set.

  attr_accessor :plugin

  def initialize(plug)
    @plugin = plug
  end

  def halt(*args)
    raise Halt.new(*args)
  end

  def haltcore(*args)
    raise HaltCore.new(*args)
  end
  
  def debug(message, exception=nil)
    @plugin.debug(message, exception) if @plugin
  end

  def post(*args)
    @plugin.post(*args) if @plugin
  end

  # Timers

  def add_timer(symbol, interval, repeat=false, data=nil)
    t = Timer.new(self, symbol, interval, repeat, data)
    @plugin.timers << t
    t
  end

  def del_timer(t)
    @plugins.del_timer(t)
  end
end
