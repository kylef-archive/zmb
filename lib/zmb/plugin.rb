require 'zmb/plugins'
require 'zmb/nv'

class Plugin
  include ZMB::Plugins
  include ZMB::NV

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

  def initialize(core, s)
    @zmb = core
    @timers = Array.new
  end

  def plugins
    zmb.plugins
  end

  def config_dir
    d = File.join(zmb.config_dir, self.class.name.to_s)
    Dir.mkdir(d) unless File.exists?(d)
    d
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

  include ZMB::Plugins

  attr_accessor :plugin

  def initialize(plug)
    @plugin = plug
  end

  def zmb
    @plugin.zmb
  end

  def plugins
    @plugin.plugins
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
