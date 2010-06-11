require 'digest'
require 'zmb/timer'

class HttpWatch
  attr_accessor :settings
  
  def initialize(sender, s)
    @delegate = sender
    @settings = s
    @settings['urls'] = Array.new unless @settings.has_key?('urls')
    @settings['interval'] = 60*5 unless @settings.has_key?('interval')
    
    @delegate.timer_add(Timer.new(self, :check, @settings['interval'], true))
  end
  
  def check
    @settings['urls'].each do |url|
      hash = Digest::SHA256.hexdigest(url['url'].get.body)
      
      if hash != url['hash'] then
        @delegate.instances[url['instance']].message(url['sender'], "#{url['url']} has been changed")
      end
      
      url['hash'] = hash
    end
  end
  
  def commands
    {
      'watch' => [:watch, 1, {}],
      'stop-watching' => :remove
    }
  end
  
  def watch(e, url)
    @settings['urls'] << {
      'instance' => e.delegate.instance,
      'sender' => e.sender,
      'url' => url,
      'hash' => Digest::SHA256.hexdigest(url.get.body)
    }
    
    "#{url} is now being watched"
  end
  
  def remove(e, url)
    u = @settings['urls'].find do |u|
      (u['url'] == url) and (u['instance'] == e.delegate.instance) and (u['sender'] == e.sender)
    end
    
    if u then
      @settings['urls'].delete(u)
      "#{url} is no longer being watched"
    else
      "No url match for this url on this irc server from user/channel"
    end
  end
end

Plugin.define do
  name 'httpwatch'
  description 'Watch a url for changes'
  object HttpWatch
end
