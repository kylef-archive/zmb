require 'ftools'

class Log
  def initialize(sender, s)
    @delegate = sender
  end
  
  def log_file(instance, channel)
    path = File.join(@delegate.settings_manager.directory, 'logs', instance)
    File.makedirs(path)
    File.join(path, "#{channel}-#{Time.now.strftime('%d%m%Y')}.log")
  end
  
  def event(sender, e)
    if e.respond_to?('channel') and e.respond_to?('line') and e.channel then
      File.open(log_file(e.delegate.instance, e.channel), 'a+') { |f| f.write(e.line + "\n") }
    end
  end
end

Plugin.define do
  name 'log'
  description 'log everything received from irc'
  object Log
end
