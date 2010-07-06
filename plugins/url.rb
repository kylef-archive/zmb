require 'uri'
require 'net/http'

class URL
  def initialize(sender, s) ;end
  
  def commands
    {
      'head' => :head,
      'url' => [:get, { :permission => 'admin' }],
      'bitly' => :bitly,
      'isgd' => :isgd,
      'tinyurl' => :tinyurl,
      'dpaste' => :dpaste,
      'pastie' => :pastie_command,
      'ppastie' => [:private_pastie_command, { :help => 'Create a private pastie' }],
    }
  end
  
  def head(e, url)
    resp = url.http('head')
    
    if resp.code == "301" or resp.code == "302" then
      "#{resp.code} - #{resp['location']}"
    elsif resp.code == "404" then
      "404 - Page not found"
    else
      "#{resp.code}"
    end
  end
  
  def get(e, url)
    url.get.body
  end
  
  def bitly(e, link)
    'http://bit.ly/api'.get({ :url => link }).body
  end
  
  def isgd(e, link)
    'http://is.gd/api.php'.get({ :longurl => link }).body
  end
  
  def tinyurl(e, link)
    'http://tinyurl.com/api-create.php'.get({ :url => link }).body
  end
  
  def dpaste(e, data)
    resp, body = 'http://dpaste.de/api/'.post({ :content => data })
    body = body[1..-2] if body =~ /^".+"$/ # Remove any quotation marks if there are any
    body
  end
  
  def pastie(data, is_private=false, format='plaintext')
    resp, body = 'http://pastie.org/pastes'.post({ :paste => {
      :body => data,
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
