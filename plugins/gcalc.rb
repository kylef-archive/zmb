require 'uri'

class GCalc <Plugin
  name :gcalc
  description 'Execute a expression using google calculator.'

  def initialize(sender, settings); end
  
  def commands
    {
      'gcalc' => [:calc, 1, {
        :help => 'Execute a expression using google calculator.',
        :example => '1 + 2' }]
    }
  end
  
  def calc(e, search)
    resp, body = 'http://www.google.com/search'.get({ :q => URI.escape(search, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")) })
    
    if resp.code == '200' then
      if body.include?('<img src=/images/calc_img.gif width=40 height=30 alt="">')
        body.split('<img src=/images/calc_img.gif width=40 height=30 alt="">')[1].split('<b>')[1].split('</b>')[0].sub('<font size=-2> </font>', '').sub('&#215;', '*').sub('<sup>', '**').sub('</sup>', '')
      else
        'Your expression can\'t be evaluated by the google calculator'
      end
    else
      "http error (#{resp.code})"
    end
  end
end
