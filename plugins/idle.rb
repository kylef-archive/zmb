class Idle
  def initialize(sender, settings)
    @channels = Hash.new
  end
  
  def to_json(*a)
    { 'plugin' => 'idle' }.to_json(*a)
  end
  
  def event(sender, e)
    if e.message? and e.respond_to?('channel') then
      @channels[e.channel] = Time.now if not e.message.include?('idle')
    end
  end
  
  def commands
    {
      'idle' => [:idle, 1, { :help => 'How long has this channel been idle?'}],
    }
  end
  
  def idle(e, channel=nil)
    channel = e.channel if not channel
    
    if not @channels.has_key?(channel) then
      "I have not seen any messages in #{channel}"
    else
      diff = Time.now - @channels[channel]
      
      if diff < 60 then
        msg = "#{Integer(diff)} seconds ago"
      elsif diff < 3600 then
        msg = "#{Integer(diff/60)} minutes ago"
      elsif diff < 86400 then
        msg = "about #{Integer(diff/3600)} hours ago"
      else
        msg = "#{Integer(diff/86400)} days ago"
      end
      
      "Last message in #{channel} was #{msg}"
    end
  end
end

Plugin.define do
  name 'idle'
  description 'Let\'s you see how idle a channel has been'
  object Idle
end
