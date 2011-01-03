class Plugin
  attr_accessor :zmb, :timers

  class << self
    def self.attr_rw(*attrs)
      attrs.each do |attr|
        class_eval %Q{
          def #{attr}(val=nil)
            val.nil? ? @#{attr} : @#{attr} = val
          end
        }
      end
    end

    attr_rw :name, :description, :definition_file
  end

  def initialize(delegate, s)
    @timers = Array.new
  end

  def debug(message, exception=nil)
    zmb.debug(self, message, exception) if @zmb
  end

  # Timers

  def add_timer(symbol, interval, repeat=false, data=nil)
    t = Timer.new(self, symbol, interval, repeat, data)
    @timers << t
    t
  end

  def del_timer(t)
    @timers.delete(t)
  end
end
