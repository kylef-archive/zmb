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
      :key => 'ABQIAAAAhwR5TtcQxY9fSuKy7yrBJhQ-sC4I4KvMQ8RG81t2M9sVc21w2xQUb9Dipx99m8XrHBsa3OctXe2rQw',
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
