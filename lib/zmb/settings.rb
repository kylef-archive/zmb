require 'json'

class Settings
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
  
  def save(key, data)
    f = File.open setting_path(key), 'w'
    f.write data.to_json
    f.close
  end
end