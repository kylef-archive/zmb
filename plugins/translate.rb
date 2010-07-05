require 'cgi'

class Translate
  def initialize(sender, s) ;end
  
  def commands
    {
      'translate' => [:translate, {
        :usage => 'to from message',
        :example => 'en fr Hello',
      }],
    }
  end
  
  def translate(e, to, from, message)
    request = JSON.parse("http://ajax.googleapis.com/ajax/services/language/translate".get({
      :v => '1.0',
      :key => 'ABQIAAAAtWAKkpCW6vL4tULVhqm_ZxQVlmwHIG1k2CM6GldPK9kOhyhAchSCYvJg4eFXVQuYYE7r4s1oNbga9A',
      :langpair => "#{to}%7C#{from}",
      :q => CGI.escape(message)
    }).body)
    
    if request['responseStatus'] == 200 then
      request['responseData']['translatedText']
    elsif request['responseStatus'] == 400
      request['responseDetails']
    else
      "Unknown error occured"
    end
  end
end

Plugin.define do
  name 'translate'
  object Translate
end
