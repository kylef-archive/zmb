require 'uri'
require 'net/http'
require 'cgi'

class URL
  def initialize(sender, s) ;end
  
  def http(host, port=80, path='/', type='get', query_string={})
    http = Net::HTTP.new(host, port)
    query_string = query_string.to_query_string if query_string.class == Hash
    http.start do |h|
      case type
        when 'get' then h.get(path + '?' + query_string)
        when 'post' then h.post(path, query_string)
        when 'head' then h.head(path + '?' + query_string)
      end
    end
  end
  
  def http_uri(url, type='get')
    u = URI.parse(url)
    u.path = '/' if u.path.size == 0
    u.query = '' if not u.query
    http(u.host, u.port, u.path, type, u.query)
  end
  
  def commands
    {
      'head' => :head,
      'url' => [:get, 1, { :permission => 'admin' }],
      'bitly' => :bitly,
      'isgd' => :isgd,
      'tinyurl' => :tinyurl,
      'dpaste' => :dpaste,
      'pastie' => :pastie_command,
      'ppastie' => [:private_pastie_command, 1, { :help => 'Create a private pastie' }],
    }
  end
  
  def head(e, url)
    resp = http_uri(url, 'head')
    
    if resp.code == "301" or resp.code == "302" then
      "#{resp.code} - #{resp['location']}"
    elsif resp.code == "404" then
      "404 - Page not found"
    else
      "#{resp.code}"
    end
  end
  
  def get(e, url)
    resp, body = http_uri(url)
    body
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
