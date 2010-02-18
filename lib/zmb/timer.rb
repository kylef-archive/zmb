class Timer
  require 'date'
  
  attr_accessor :delegate
  
  def initialize(delegate, symbol, interval, repeat=false) # interval is in seconds (decimals accepted)
    @delegate = delegate
    @symbol = symbol
    @interval = interval
    @repeat = repeat
    
    @fire_at = Time.now + interval
  end

  def fire(sender)
    @delegate.send @symbol

    if not @repeat
      sender.timer_delete(self) if sender.respond_to?('timer_delete')
    else
      @fire_at = Time.now + @interval
    end
  end
  
  def timeout
    @fire_at - Time.now
  end
end
