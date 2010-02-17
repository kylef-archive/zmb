class Event
  attr_accessor :sender, :message
  
  def initialize(sender)
    @sender = sender
  end
  
  def message?
    message != nil
  end
  
  def reply(message)
    @sender.reply(self, message)
  end
end
