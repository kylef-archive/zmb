require 'resolv'
require 'socket'

class DNS
  def initialize(sender, s) ;end
  
  def commands
    {
      'dns' => [lambda { |e, host| Resolv.new.getaddress(host) }, {
        :help => 'Lookup the ip address for a domain',
        :usage => 'domain',
        :example => 'apple.com' }],
      'rdns' => [:rdns, {
        :help => 'Perform a reverse dns on a host',
        :usage => 'ip',
        :example => '17.149.160.49' }],
      'whois' => [:whois, 1, {
        :help => 'perform a whois on a domain',
        :usage => 'domain',
        :example => 'apple.com' }],
    }
  end
  
  def rdns(e, ip)
    begin
      Resolv.new.getname(ip)
    rescue Resolv::ResolvError
      ip
    end
  end
  
  def whois(e, domain)
    begin
      require 'whois'
    rescue Exception
      'command depends on whois gem: http://www.ruby-whois.org/'
    end
    
    a = Whois.query(domain)
    
    if a.available? then
      "#{domain} is availible"
    else
      t = a.technical
      c = "Created on #{a.created_on}"
      c += " by #{t.name}" if t
      c
    end
  end
end

Plugin.define do
  name 'dns'
  description 'resolve dns'
  object DNS
end
