require 'resolv'
require 'socket'

class DNS
  def initialize(sender, s) ;end
  
  def commands
    {
      'dns' => :dns,
      'rdns' => :rdns,
      'whois' => [:whois, 1, { :help => 'perform a whois on a domain' }],
    }
  end
  
  def dns(e, host)
    Resolv.new.getaddress(host)
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
