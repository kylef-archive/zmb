class System
  def initialize(sender, settings) ;end
  
  def to_json(*a)
    { 'plugin' => 'system' }.to_json(*a)
  end
  
  def commands
    require 'zmb/commands'
    {
      'uptime' => Command.new(self, :uptime, 0, 'Server uptime'),
      'date' => Command.new(self, :date, 0, 'Display the server date/time'),
    }
  end
  
  def uptime(e)
    `uptime`.chomp
  end
  
  def date(e)
    "#{Time.now}"
  end
end

Plugin.define do
  name "system"
  description "System infomation (uptime, date)"
  object System
end
