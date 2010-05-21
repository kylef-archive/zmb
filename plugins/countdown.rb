require 'time'

class Countdown
  attr_accessor :settings
  
  def initialize(sender, settings)
    @settings = { 'countdown' => {} }
    settings['countdown'].each{ |k,v| @settings['countdown'][k] = Time.parse(v) } if settings.has_key?('countdown')
  end
  
  def commands
    {
      'countdown' => [:countdown, 1, { :usage => 'key' }],
      'countdowns' => [:countdowns, 0],
      'add-countdown' => [:add, 2, { :permission => 'countdown', :usage => 'key date/time', :example => 'xmas 25-12-2010' }],
      'rm-countdown' => [:remove, 1, { :permission => 'countdown', :usage => 'key' }]
    }
  end
  
  def countdown(e, key)
    if @settings['countdown'].has_key?(key) then
      @settings['countdown'][key].since_words
    else
      "No such countdown"
    end
  end
  
  def countdowns(e)
    @settings['countdown'].keys.join(', ')
  end
  
  def add(e, key, time)
    @settings['countdown'][key] = Time.parse(time)
    "Countdown #{key} added"
  end
  
  def remove(e, key)
    @settings['countdown'].delete(key)
    "Countdown #{key} removed"
  end
end

Plugin.define do
  name 'countdown'
  object Countdown
end
