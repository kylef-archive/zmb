require 'uri'
require 'net/http'
require 'commands'

class URL <Plugin
  extend Commands

  name :url
  description 'URL shortening and paste websites'

  command :head do
    regex /^(\S+)$/

    call do |m, url|
      resp = url.http('head')
    
      if resp.code == "301" or resp.code == "302" then
        "#{resp.code} - #{resp['location']}"
      elsif resp.code == "404" then
        "404 - Page not found"
      else
        "#{resp.code}"
      end
    end
  end

  command :get do
    permission :admin
    regex /^(\S+)$/

    call do |m, url|
      url.get.body
    end
  end
  
  command :bitly do
    help 'Shorten a URL'
    regex /^(\S+)$/

    call do |m, url|
      'http://bit.ly/api'.get({ :url => url }).body
    end
  end

  command :isgd do
    help 'Shorten a URL'
    regex /^(\S+)$/

    call do |m, url|
      'http://is.gd/api.php'.get({ :longurl => url }).body
    end
  end

  command :tinyurl do
    help 'Shorten a URL'
    regex /^(\S+)$/

    call do |m, url|
      'http://tinyurl.com/api-create.php'.get({ :url => url }).body
    end
  end

  command!(:dpaste) do |m, data|
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

  command!(:pastie) do |m, data|
    pastie(data)
  end

  command :ppastie do
    help 'Upload a private pastie'

    call do |m, data|
      pastie(data, true)
    end
  end
end
