require 'commands'

class Wiki <Plugin
  extend Commands

  name :wiki

  def initialize(sender, settings)
    super(sender, settings)
    @namespaces = Hash.new
  end

  def irc_message(connection, message)
    message.scan(/\[\[(.+)\]\]/).each do |match|
      match = match.first
      if match.include?(':')
        ns, path = match.split(':', 2)
      else
        ns = 'Self'
        path = match
      end

      if @namespaces.has_key?(ns)
        message.reply("#{@namespaces[ns]}#{path.sub(' ', '_')}")
      end
    end
  end

  command :add_namespace do
    help 'Add a wiki namespace'
    permission :admin
    regex /^(\S+)\s+(\S+)$/

    call do |m, ns, uri|
      @namespaces[ns] = uri
      "#{ns} has been set to #{uri}"
    end
  end

  command :rm_namespace do
    help 'Remove a wiki namespace'
    permission :admin
    regex /^(\S+)$/

    call do |m, ns|
      @namespaces.delete(ns)
      "#{ns} has been removed"
    end
  end

  command :namespaces do
    help 'List all wiki namespaces'
    permission :admin

    call do |m|
      if @namespaces.count > 0
        @namespaces.keys.join(', ')
      else
        'There are no namespaces.'
      end
    end
  end
end
