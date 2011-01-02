require 'fileutils'

begin
  require 'json'
rescue LoadError
  require 'rubygems'
  gem 'json'
end

class Settings
  attr_accessor :directory
  
  def initialize(directory)
    if not File.exist?(directory) then
      FileUtils.makedirs(directory)
    end
    
    if not File.directory?(directory) and not File.owned?(directory) then
      raise
    end
    
    @directory = directory
  end
  
  def setting_path(key)
    key = key.to_s if key.class != String
    File.join(@directory, key.gsub('/', '_') + '.json')
  end
  
  def setting(key)
    begin
      JSON.parse(File.read(setting_path(key)))
    rescue
      {}
    end
  end
  
  def get(object, name, default=nil)
    s = setting(object)
    
    if s.respond_to?('has_key?') and s.has_key?(name) then
      s[name]
    else
      default
    end
  end
  
  def save(plugin_name, s={})
    f = File.open setting_path(plugin_name), 'w'
    s = s.settings if s.respond_to?('settings')
    f.write s.to_json
    f.close
  end
end
