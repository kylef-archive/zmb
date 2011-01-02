class AutoRejoin <Plugin
  name :autorejoin
  description  'auto rejoin a irc channel once we have been kicked'

  def event(sender, e)
    if e.command == 'kick' then
      e.delegate.write("JOIN #{e.channel}") if e.delegate.nick == e.name
    end
  end
end
