class NickServ
  def initialize(sender, s)
    @password = s['password'] if s.has_key?('password')
  end
  
  def settings
    { 'plugin' => 'nickserv', 'password' => @password }
  end
  
  def self.wizard
    {
      'password' => { 'help' => 'Password to authenticate with NickServ.', 'default' => nil },
    }
  end
  
  def event(sender, e)
    e.delegate.message('NickServ', "IDENTIFY #{@password}") if e.command == '001' and @password
  end
  
  def commands
    {
      'nickserv' => [:set, 1, {
        :help => 'Set the NickServ password for the bot to login with.',
        :usage => 'password',
      }],
    }
  end
  
  def set(e, password=nil)
    if password then
      @password = password
      "Password set to #{@password}"
    else
      @password = nil
      "Password unset."
    end
  end
end

Plugin.define do
  name "nickserv"
  description "Authenticates the zmb bot with NickServ."
  object NickServ
end
