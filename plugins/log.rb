require 'ftools'

class Log <Plugin
  name :log
  description 'Log every message to a log file'

  def initialize(sender, s)
    @delegate = sender
  end
  
  def log_file(instance, channel)
    path = File.join(@delegate.settings_manager.directory, 'logs', instance)
    File.makedirs(path)
    File.join(path, "#{channel}-#{Time.now.strftime('%d%m%Y')}.log")
  end
  
  def time
    t = Time.now
    "#{sprintf("%.2i", t.hour)}:#{sprintf("%.2i", t.min)}:#{sprintf("%.2i", t.sec)}"
  end
  
  def log(instance, channel, message)
    File.open(log_file(instance, channel), 'a+') { |f| f.write("[#{time}] #{message}" + "\n") }
  end
  
  def event(sender, e)
    if e.respond_to?('channel') and e.channel then
      if e.command == 'join' then
        log(e.delegate.instance, e.channel, "*** Joins: #{e.name} (#{e.userhost})")
      elsif e.command == 'part'
        log(e.delegate.instance, e.channel, "*** Parts: #{e.name} (#{e.userhost})")
      elsif e.command  == 'kick'
        log(e.delegate.instance, e.channel, "*** #{e.nick} was kicked by #{e.name} (#{e.message})")
      elsif e.message?
        log(e.delegate.instance, e.channel, "#{e.name}: #{e.message}")
      end
    end
  end
end
