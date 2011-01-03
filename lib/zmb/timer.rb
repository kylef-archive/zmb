class Timer
  require 'date'

  attr_accessor :delegate, :symbol

  def initialize(delegate, symbol, interval, repeat=false, data=nil) # interval is in seconds (decimals accepted)
    @delegate = delegate
    @symbol = symbol
    @interval = interval
    @repeat = repeat
    @data = data

    @fire_at = Time.now + interval
  end

  def debug(message, exception=nil)
    @delegate.debug(message, exception)
  end

  def fire
    begin
      if @data then
        @delegate.send(@symbol, @data)
      else
        @delegate.send(@symbol)
      end

      debug("Fired timer #{@symbol}")
    rescue Exception
      debug("Timer #{@symbol} failed", $!)
    end

    if not @repeat
      invalidate
    else
      @fire_at = Time.now + @interval
    end
  end

  def timeout
    @fire_at - Time.now
  end

  def invalidate
    debug("Invalidating timer #{@symbol}")
    @delegate.del_timer(self)
  end
end
