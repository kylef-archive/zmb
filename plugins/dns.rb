require 'resolv'
require 'socket'

require 'commands'

class DNS <Plugin
  extend Commands

  name :dns
  description 'resolve dns'

  command :dns do
    help 'Lookup the IP address for a domain name'
    usage 'domain' => 'apple.com'

    call { |m, host| Resolv.new.getaddress(host) }
  end

  command :rdns do
    help 'Perform a reverse DNS lookup on a host'
    usage 'ip' => '17.149.160.49'

    call do |m, ip|
      begin
        Resolv.new.getname(ip)
      rescue Resolv::ResolvError
        ip
      end
    end
  end

  command :whois do
    help 'Perform a whois on a domain'
    usage 'domain' => 'apple.com'

    call do |m, domain|
      begin
        require 'whois'

        a = Whois.query(domain)

        if a.available? then
          "#{domain} is availible"
        else
          t = a.technical
          c = "Created on #{a.created_on}"
          c += " by #{t.name}" if t
          c
        end
      rescue Exception
        'command depends on whois gem: http://www.ruby-whois.org/'
      end
    end
  end
end
