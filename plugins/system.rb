class System
  def initialize(sender, s) ;end
  
  def commands
    {
      'uptime' => [:uptime, 0, { :help => 'Server uptime' }],
      'date' => [:date, 0, { :help => 'Display the server date/time' }],
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
