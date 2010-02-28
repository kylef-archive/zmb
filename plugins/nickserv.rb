class NickServ
  def initialize(sender, settings)
    @password = settings['password'] if settings.has_key?('password')
  end
  
  def to_json(*a)
    { 'plugin' => 'nickserv', 'password' => @password }.to_json(*a)
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
    require 'zmb/commands'
    {
      'nickserv' => PermCommand.new('admin', self, :set, 1, 'Set your NickServ password.'),
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
