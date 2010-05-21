class Timer
  require 'date'
  
  attr_accessor :delegate
  
  def initialize(delegate, symbol, interval, repeat=false, data=nil) # interval is in seconds (decimals accepted)
    @delegate = delegate
    @symbol = symbol
    @interval = interval
    @repeat = repeat
    @data = data
    
    @fire_at = Time.now + interval
  end

  def fire(sender)
    begin
      if @data then
        @delegate.send @symbol, @data
      else
        @delegate.send @symbol
      end
    rescue Exception
      
    end

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
