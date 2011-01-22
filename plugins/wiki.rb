require 'commands'

class Wiki <Plugin
  extend Commands

  name :wiki

  def irc_message(connection, message)
    message.scan(/\[\[(.+)\]\]/).each do |match|
      match = match.first
      if match.include?(':')
        ns, path = match.split(':', 2)
      else
        ns = 'Self'
        path = match
      end

      if nv?(ns)
        message.reply("#{nv(ns)}#{path.gsub(' ', '_')}")
      else
        message.reply("Wiki namespace (#{ns}) does not exist.")
      end
    end
  end

  command :add_namespace do
    help 'Add a wiki namespace'
    permission :admin
    usage 'namespace uri' => 'Self http://en.wikipedia.org/wiki/'
    regex /^(\S+)\s+(\S+)$/

    call do |m, ns, uri|
      nv(ns, uri)
      "#{ns} has been set to #{uri}"
    end
  end

  command :rm_namespace do
    help 'Remove a wiki namespace'
    permission :admin
    regex /^(\S+)$/

    call do |m, ns|
      nv!(ns)
      "#{ns} has been removed"
    end
  end

  command :namespaces do
    help 'List all wiki namespaces'
    permission :admin

    call do |m|
      load_nv if @nv.nil?

      if @nv.count > 0
        @nv.keys.join(', ')
      else
        'There are no namespaces.'
      end
    end
  end
end
