require 'net/http'
require 'rexml/document'

class Weather <Plugin
  name :weather
  description 'Get the weather for a town/city'

  def initialize(sender, s) ;end
  
  def commands
    {
      'weather' => [:weather, 1, {
        :help => 'Check the weather',
        :usage => 'location',
        :example => 'Cupertino' }],
    }
  end
  
  def weather(e, location=nil)
    if not location then
      if not (e.respond_to?('user') and e.user and e.user.authenticated?) then
        return 'Please supply a location'
      elsif e.user.location and e.user.location != '' then
        location = e.user.location
      else
        return "No location set for #{e.user}"
      end
    end
    
    xml_data = 'http://www.google.com/ig/api'.get({ :weather => location }).body
    doc = REXML::Document.new(xml_data)
    
    begin
      info = doc.root.elements['weather/forecast_information']
      city = info.elements['city'].attributes['data']
      
      current = doc.root.elements['weather/current_conditions']
      condition = current.elements['condition'].attributes['data']
      temp_c = current.elements['temp_c'].attributes['data']
      temp_f = current.elements['temp_f'].attributes['data']
      humidity = current.elements['humidity'].attributes['data']
      wind_condition = current.elements['wind_condition'].attributes['data']
      
      tomorrow = doc.root.elements['weather/forecast_conditions']
      tomorrow_cond = tomorrow.elements['condition'].attributes['data']
      
      "#{condition} #{temp_c}C/#{temp_f}F #{humidity} #{wind_condition} for #{city}\n"+
      "Forcast for tomorrow #{tomorrow_cond}"
    rescue NoMethodError
      "Command failed, maybe the location is invalid?"
    end
  end
end
