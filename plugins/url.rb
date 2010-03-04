require 'uri'
require 'net/http'
require 'cgi'

class URL
  def initialize(sender, s) ;end
  
  def to_query_string(h)
    h.map { |k, v| 
      if v.instance_of?(Hash)
        v.map { |sk, sv|
          "#{k}[#{sk}]=#{sv}"
        }.join('&')
      else
        "#{k}=#{v}"
      end
    }.join('&')
  end
  
  def http(host, port=80, path='/', type='get', query_string={})
    http = Net::HTTP.new(host, port)
    resp, body = http.start do |http|
      case type
        when 'get' then http.get(path + '?' + to_query_string(query_string))
        when 'post' then http.post(path, to_query_string(query_string))
      end
    end
  end
  
  def commands
    {
      'bitly' => :bitly,
      'isgd' => :isgd,
      'tinyurl' => :tinyurl,
      'dpaste' => :dpaste,
      'pastie' => :pastie_command,
      'ppastie' => [:private_pastie_command, 1, { :help => 'Create a private pastie' }],
    }
  end
  
  def bitly(e, link)
    resp, body = http('bit.ly', 80, '/api', 'get', { :url => link })
    body
  end
  
  def isgd(e, link)
    resp, body = http('is.gd', 80, '/api.php', 'get', { :longurl => link })
    body
  end
  
  def tinyurl(e, link)
    resp, body = http('tinyurl.com', 80, '/api-create.php', 'get', { :url => link })
    body
  end
  
  def dpaste(e, data)
    resp, body = http('dpaste.de', 80, '/api/', 'post', { :content => data })
    body = body[1..-2] if body =~ /^".+"$/ # Remove any quotation marks if there are any
    body
  end
  
  def pastie(data, is_private=false, format='plaintext')
    resp, body = http('pastie.org', 80, '/pastes', 'post', { :paste => {
      :body => CGI.escape(data),
      :parser => format,
      :restricted => is_private,
      :authorization => 'burger'
    }})
    
    puts resp.code
    
    if resp.code == '302' then
      resp['location']
    else
      body
    end
  end
  
  def pastie_command(e, data)
    pastie(data)
  end
  
  def private_pastie_command(e, data)
    pastie(data, true)
  end
end

Plugin.define do
  name 'url'
  description 'URL shortening and paste websites'
  object URL
end
