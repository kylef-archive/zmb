class PluginBuilder
  attr_accessor :plugin
  
  def initialize(&block)
    @plugin = Plugin.new
    @block = block
  end
  
  def build
    instance_eval(&@block)
  end
  
  def name(value)
    @plugin.name = value
  end
  
  def description(value)
    @plugin.description = value
  end
  
  def object(value)
    @plugin.object = value
  end
end

class Plugin
  attr_accessor :name, :description, :object, :definition_file
  
  def self.define(&block)
    builder = PluginBuilder.new(&block)
    builder.build
    builder.plugin
  end
end
