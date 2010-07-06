require 'rss/1.0'
require 'rss/2.0'
require 'rss/atom'
require 'zmb/timer'

class Feeds
  attr_accessor :settings
  
  def initialize(sender, s={})
    @delegate = sender
    @settings = s
    @settings['interval'] = 10 unless settings.has_key?('interval')
    @settings['instances'] = Array.new unless settings.has_key?('instances')
    @settings['feeds'] = Array.new unless settings.has_key?('feeds')
    
    setup_timer
  end
  
  def setup_timer
    @delegate.timer_delete(self)
    @delegate.timer_add(Timer.new(self, :timer, (@settings['interval'] * 60), true))
  end
  
  def timer(e=nil)
    @settings['feeds'].each do |feed|
      begin
          rss = RSS::Parser.parse(feed['feed'].get().body, false)
          rss.items.each do |item|
            link = item.link.to_s
            link = $1 if link =~ /href="([\w:\/\.\?]*)"/
            
            break if feed['link'] == link
            @delegate.instances[feed['instance']].message(feed['sender'], "RSS: #{item.title.to_s.gsub(/<\/?[^>]*>/, "")} (#{link})")
          end
          
          link = rss.items[0].link.to_s
          link = $1 if link =~ /href="([\w:\/\.\?]*)"/
          feed['link'] = link
      rescue Exception
        @delegate.instances[feed['instance']].message(feed['sender'], "RSS: #{feed['feed']} failed")
      end
    end
  end
  
  def commands
    {
      'rss-interval' => [:interval, 1, {
        :permission => 'admin',
        :help => 'Set the interval to automatically check rss feeds',
        :usage => 'minutes',
        :example => '15' }],
      'rss-list' => [:list, 0  , {
          :permission => 'admin' }],
      'rss-subscribe' => [:add, 1, {
        :permission => 'admin',
        :help => 'Subscribe to a rss feed' }],
      'rss-scan' => [:timer, 0, { :permission => 'admin', :help => 'Rescan RSS feeds for news' }],
      'rss-unsubscribe' => [:remove, 1, {
        :permission => 'admin',
        :help => 'Unsubscribe from a rss feed' }],
    }
  end
  
  def interval(e, i)
    @settings['interval'] = Integer(i)
    setup_timer
    "RSS interval set to #{@settings['interval']}"
  end
  
  def list(e)
    if @settings['feeds'].count > 0 then
      count = 0
      @settings['feeds'].map{ |feed| "#{count+=1}: #{feed['feed']} (#{feed['instance']}/#{feed['sender']})" }.join("\n")
    else
      "No feeds"
    end
  end
  
  def add(e, feed)
    @settings['feeds'] << {
      'feed' => feed,
      'link' => nil,
      'instance' => e.delegate.instance,
      'sender' => e.sender
    }
    
    "Feed #{feed} added"
  end
  
  def remove(e, feed)
    begin
      feed_id = Integer(feed) - 1
      f = @settings['feeds'].at(feed_id)
      
      if feed then
        @settings['feeds'].delete_at(feed_id)
        "#{f['feed']} deleted"
      else
        "No feed with index: #{feed}"
      end
    rescue ArgumentError
      count = 0
      @settings['feeds'].reject{ |f| not ((f['feed'] == feed) and (f['instance'] == e.delegate.instance) and (f['sender'] == e.sender)) }.map do |f|
        count =+ 1
        @settings['feeds'].delete(f)
      end

      "#{count} feeds removed"
    end
  end
end

Plugin.define do
  name 'rss'
  description 'Subscribe and watch RSS/ATOM feeds'
  object Feeds
end
