class PluginManager
  attr_accessor :plugin_sources, :plugins
  
  def initialize(delegate=nil)
    @delegate = delegate
    @plugins = Array.new
    @plugin_sources = Array.new
  end
  
  def plugin(name)
    plugin = @plugins.find{|plugin| plugin.name == name}
    
    if plugin then
      plugin.object
    else
      nil
    end
  end
  
  def load_plugin_source(file)
    begin
      definition = instance_eval(File.read(file))
      definition.definitition_file = File.expand_path(file)
      @plugins << definition
    rescue Exception
      @delegate.debug(self, "Cannot load source `#{file}`", $!)
    end
  end
  
  def add_plugin_source(directory)
    @plugin_sources << directory
    
    definition_files = Dir[
      File.join(File.expand_path(directory), "*.rb"),
      File.join(File.expand_path(directory), "*", "plugin.rb")
    ]
    
    definition_files.map do |file|
      load_plugin_source(file)
    end
  end
  
  def refresh_plugin_sources
    sources = @plugin_sources
    
    @plugins = Array.new
    @plugin_sources = Array.new
    
    sources.each{|directory| add_plugin_source directory}
  end
  
  def reload_plugin(name)
    plugin = @plugins.find{|plugin| plugin.name == name}
    
    if plugin then
      @plugins.delete(plugin)
      reloaded = load_plugin_source plugin.definitition_file
      @plugins << plugin if not reloaded
      reloaded
    end
  end
end

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
  attr_accessor :name, :description, :object, :definitition_file
  
  def self.define(&block)
    builder = PluginBuilder.new(&block)
    builder.build
    builder.plugin
  end
end
