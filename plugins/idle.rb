class Idle
  def initialize(sender, s)
    @channels = Hash.new
  end
  
  def event(sender, e)
    if e.message? and not 
      e.message.include?('idle') and e.respond_to?('channel') then
      @channels[e.channel] = Time.now if not e.message.include?('idle')
    end
  end
  
  def commands
    {
      'idle' => [:idle, 1, { :help => 'How long has this channel been idle?' }],
    }
  end
  
  def idle(e, channel=nil)
    channel = e.channel if not channel
    
    if not @channels.has_key?(channel) then
      "I have not seen any messages in #{channel}"
    else      
      "Last message in #{channel} was #{@channels[channel].since_words}"
    end
  end
end

Plugin.define do
  name 'idle'
  description 'Let\'s you see how idle a channel has been'
  object Idle
end
