require 'uri'

class GCalc
  def initialize(sender, settings); end
  
  def commands
    {
      'gcalc' => [:calc, 1, {
        :help => 'Execute a expression using google calculator.',
        :example => '1 + 2' }]
    }
  end
  
  def calc(e, search)
    http = Net::HTTP.new('www.google.com', 80)
    resp, body = http.start do |h|
        h.get("/search?q=#{URI.escape(search, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}")
    end
    
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

Plugin.define do
  name 'gcalc'
  description 'Execute a expression using google calculator.'
  object GCalc
end
