require 'commands'

class Factoids <Plugin
  extend Commands

  name :factoids

  def irc_message(connection, message)
    if message =~ /^what(\s+)is(\s+)(\S+)\??$/i
      message.reply(nv[$3]) if nv.key?($3)
    elsif message =~ /^tell(\s+)(\S+)(\s+)about(\s+)(\S+)$/
      message.reply("#{$2}: #{nv[$5]}") if nv.key?($5)
    elsif message =~ /^(\S+)(\s+)is(\s+)also(\s+)(.+)$/i
      nv[$1] = "#{nv[$1]} #{$5}" if nv?.key($1)
    elsif message =~ /^(\S+)(\s+)is(\s+)(.+)$/
      nv[$1] = $4
    elsif message =~ /^(\S+)\?$/
      message.reply(nv[$1]) if nv.key?($1)
    end
  end

  command :forget_about do
    help 'Delete a factoid'
    regex /^(\S+)$/

    call do |m, factoid|
      if nv.delete(factoid).nil?
        "#{factoid}: Factoid not found."
      else
        "I have forgot about #{factoid}."
      end
    end
  end

  command :factoids do
    help 'List all the factoids I know'

    call do |m|
      load_nv if @nv.nil?

      if @nv.count > 0
        "#{@nv.keys.join(', ')}"
      else
        "I don't know anything!"
      end
    end
  end
end
