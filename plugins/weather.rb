require 'net/http'
require 'rexml/document'

class Weather
  def initialize(sender, s) ;end
  
  def commands
    {
      'weather' => [:weather, 1],
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
    
    location = location.sub(' ', '+')
    url = "http://www.google.com/ig/api?weather=#{location}"
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
    doc = REXML::Document.new(xml_data)
    
    info = doc.root.elements['weather/forecast_information']
    city = info.elements['city'].attributes['data']
    
    current = doc.root.elements['weather/current_conditions']
    condition = current.elements['condition'].attributes['data']
    temp = current.elements['temp_c'].attributes['data']
    humidity = current.elements['humidity'].attributes['data']
    wind_condition = current.elements['wind_condition'].attributes['data']
    
    tomorrow = doc.root.elements['weather/forecast_conditions']
    tomorrow_cond = tomorrow.elements['condition'].attributes['data']
    
    "#{condition} #{temp}c #{humidity} #{wind_condition} for #{city}\n"+
    "Forcast for tomorrow #{tomorrow_cond}"
  end
end

Plugin.define do
  name 'weather'
  object Weather
end