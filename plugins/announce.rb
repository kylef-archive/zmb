require 'zmb/timer'

class Announce
  def initialize(sender, s)
    @delegate = sender
    @announcements = Hash.new
    @announcements = s['announcements'] if s.has_key?('announcements')
    @autoindex = 1
    @autoindex = s['autoindex'] if s.has_key?('autoindex')
    
    @announcements.keys.each{ |id| timer(id) }
  end
  
  def settings
    { 'announcements' => @announcements, 'autoindex' => @autoindex }
  end
  
  def add(instance, location, interval, message)
    @announcements["#{@autoindex}"] = {
      'instance' => instance,
      'location' => location,
      'interval' => Integer(interval),
      'message' => message,
    }
    
    @autoindex += 1
    @autoindex - 1
  end
  
  def exec(id)
    if (a = @announcements.fetch("#{id}", false)) and (i = @delegate.instances.fetch(a['instance'], false)) then
      i = @delegate.instances[a['instance']]
      i.message(a['location'], a['message']) if i.respond_to?('message')
    end
  end
  
  def timer(id)
    a = @announcements["#{id}"]
    a['timer'] = Timer.new(self, :exec, a['interval'], true, id)
    @delegate.timer_add(a['timer'])
  end
  
  def delete(id)
    if (a = @announcements.fetch("#{id}", false)) then
      @delegate.timer_delete(a['timer']) if a.has_key?('timer')
      @announcements.delete("#{id}")
      true
    else
      false
    end
  end
  
  def commands
    {
      'announcements' => [:announcements, 0, {
        :permission => 'admin',
        :help => 'List all the id\'s for' }],
      'announcement' => [:announcement, 1, {
        :permission => 'admin',
        :help => 'Display infomation about a announcement',
        :usage => 'id',
        :example => '1' }],
      'announce' => [:announce, 4, {
        :permission => 'admin',
        :help => 'Add a announcement',
        :usage => 'instance location interval message',
        :example => 'efnet #zmb 600 Check github for the latest updates!' }],
      'announce-del' => [:announce_del, 1, {
        :permission => 'admin',
        :help => 'Delete a announcement',
        :usage => 'id',
        :example => '1' }],
    }
  end
  
  def announcements(e)
    if @announcements.size == 0 then
      'no announcements'
    else
      @announcements.keys.join(', ')
    end
  end
  
  def announcement(e, id)
    if (a = @announcements.fetch(id, false)) then
      "'#{a['message']}' every #{a['interval']} seconds in #{a['instance']}/#{a['location']}"
    else
      'announcement not found'
    end
  end
  
  def announce(e, *args)
    "Announcement added \##{add(*args)}"
  end
  
  def announce_del(e, id)
    if delete(id) then
      "#{id} deleted"
    else
      "#{id} not found"
    end
  end
end

Plugin.define do
  name 'announce'
  description 'Send message to a channel automatically in a certain amount of time'
  object Announce
end
