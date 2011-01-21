module Commands
  class CommandBuilder
    attr_accessor :symbol

    def self.attr_command(*attrs)
      attrs.each do |attr|
        class_eval %Q{
          def #{attr}(val)
            @command.#{attr} = val
          end
        }
      end
    end

    attr_command :help, :example
    attr_command :regex, :args
    attr_command :permission

    def initialize(symbol, &block)
      @symbol = symbol
      @block = block
    end

    def build(instance=nil)
      @command  = Command.new(@symbol)
      @command.instance = instance
      instance_eval(&@block)
      @command
    end

    def call(&block)
      @command.block(&block)
    end

    def usage(var)
      case var
      when Hash
        @command.usage, @command.example = var.shift
      when String
        @command.usage = var
      end
    end
  end

  class Command
    attr_accessor :symbol, :instance, :permission
    attr_accessor :help, :usage, :example
    attr_accessor :regex, :args

    def initialize(symbol)
      @symbol = symbol
    end

    def block(&block)
      @block = block
    end

    def call!(message, line=nil)
      if @regex
        if (rm = @regex.match(line))
          call(message, *rm.captures)
        else
          "Invalid Arguments"
        end
      elsif not @args.nil?
        if @args > 0
          call(message, *line.split(' ', @args))
        else
          call(message)
        end
      elsif line.nil?
        call(message)
      else
        call(message, line)
      end
    end

    def call(*args)
      if @instance
        @instance.instance_exec(*args, &@block)
      else
        @block.call(*args)
      end
    end
  end

  def command(symbol, &block)
    @command_builders ||= Array.new
    @command_builders << CommandBuilder.new(symbol, &block)
  end

  def command!(symbol, &block)
    @command_builders ||= Array.new

    cb = CommandBuilder.new(symbol) do
      call &block
    end

    @command_builders << cb
  end

  def commands
    @command_builders || Array.new
  end

  def new(*args, &block)
    obj = super
    obj.instance_eval do
      @commands = self.class.commands.collect{ |cb| cb.build(self) }
      def commands; @commands; end
    end
    obj
  end
end

class CommandsPlugin <Plugin
  extend Commands

  name :commands
  description 'This plugin is needed for other plugins to function properly.'

  attr_accessor :cc
  
  def initialize(sender, s={})
    super

    @cc = '.'
    @cc = s['cc'] if s.has_key?('cc')
  end

  def settings
    { 'cc' => @cc }
  end

  def command(symbol) # Find a command via symbol
    commands!.find{ |c| c.symbol == symbol }
  end

  def command!(name) # Find a command via a string
    command(name.to_sym)
  end

  def commands! # Returns a Array of all commands
    zmb.plugins.select{ |p| p.respond_to?('commands') }.collect{ |p| p.commands }.flatten
  end

  def irc_message(connection, message)
    if message[0, @cc.length] == @cc then
      line = message[@cc.length..-1].clone
    elsif message =~ /^#{connection.nick}(:|,) (.+)/
      line = $2
    elsif message.private? then
      line = message.clone
    else
      return
    end

    line.gsub!('{time}', Time.now.strftime('%H:%M:%S'))
    line.gsub!('{day}', Time.now.strftime('%d'))
    line.gsub!('{weekday}', Time.now.strftime('%A'))
    line.gsub!('{timezone}', Time.now.strftime('%Z'))
    line.gsub!('{month}', Time.now.strftime('%B'))
    line.gsub!('{year}', Time.now.strftime('%Y'))
    line.gsub!('{username}', message.opts[:user].username) if message.opts.has_key?(:user)
    line.gsub!('{points}', "#{message.opts[:bank].balance}") if message.opts.has_key?(:bank)
    line.gsub!('{channel}', message.channel.to_s) unless message.channel.nil?
    line.gsub!('{nick}', message.user.nick)
    line.gsub!('{userhost}', message.user.userhost)
    line.gsub!('{rand}', String.random)
 
    input = nil
    line.gsub!('\|', "\000p\000")

    line.split('|').each do |l|
      if l.strip =~ /^(\S+)(\s+(.+))?$/
        c = $1
        args = Array.new
        args << $3.strip unless $3.nil?
        args << input.strip unless input.nil?

        if args.count > 0
          args = args.join(' ')
          args.gsub!("\000p\000", '|')
          input = execute!(c, message, args)
        else
          input = execute!(c, message)
        end
      end
    end
    
    message.reply(input) if input
  end

  def execute(symbol, message, line=nil)
    c = command(symbol)

    if c
      # Check permissions
      if not c.permission.nil?
        return 'Users plugin not found' unless message.opts.has_key?(:user)

        if not message.opts[:user].permission?(c.permission)
          return 'Permission denied'
        end
      end

      begin
        c.call!(message, line)
      rescue ArgumentError
        "#{symbol}: Incorrect arguments"
      rescue Exception
        zmb.debug(c.instance.nil? ? self : c.instance, "#{symbol}: Command failed to execute", $!)
        "#{symbol}: Failed to execute"
      end
    else
      "#{symbol}: Command not found"
    end
  end

  def execute!(name, message, line=nil)
    execute(name.to_sym, message, line)
  end

  # Commands

  command :cc do
    usage '[control-character]' => '!'
    permission :admin

    call do |m, var|
      if var.nil?
        "Control command is set to '#{@cc}'"
      else
        @cc = var
        "Control command has been changed to '#{@cc}'"
      end
    end
  end

  command! :help do |m, command_name|
    if command_name
      c = command!(command_name)

      if c
        help = Array.new
        help << "#{command_name}: #{c.help}" unless c.help.nil?
        help << "Usage: #{c.usage}" unless c.usage.nil?
        help << "Example: #{c.example}" unless c.example.nil?

        if help.size > 0
          help.join("\n")
        else
          "#{command_name}: No help availible for this command"
        end
      else
        "#{command_name}: Command not found"
      end
    else
      # TODO: Only display commands a user has permission to execute
      commands!.collect{ |c| c.symbol.to_s }.join(', ')
    end
  end

  command :which do
    help 'Find which plugin a command belongs to.'
    usage 'command' => 'help'
    regex /^(\S+)$/

    call do |m, command_name|
        c = command!(command_name)

        if c and c.instance.class.respond_to?(:name)
        "#{c.instance.class.name}"
       elsif c
         "#{command_name} doesn't belong to any plugin"
       else
         "#{command_name}: Command not found"
       end
    end
  end

  command :commands do
    help 'List all availible commands for a plugin'
    usage 'plugin' => 'irc'
    regex /^(\S+)$/

    call do |m, plugin_name|
      p = plugin!(plugin_name)

      if p
        if not p.respond_to?(:commands)
          "#{plugin_name}: No commands availible for this plugin."
        elsif p.commands.count > 0
          p.commands.collect{ |c| c.symbol.to_s }.join(', ')
        else
          "#{plugin_name}: No commands availible for this plugin."
        end
      else
        "#{plugin_name}: Plugin not found."
      end
    end
  end

  command :eval do
    help 'Execute ruby code'
    example '1 * 2'
    permission :admin

    call do |m, string|
      begin
        "#{eval string}"
      rescue Exception
        "#{$!.message}\n#{$!.inspect}"
      end
    end
  end

  command :peval do
    help 'Execute ruby code from within a plugin'
    example 'irc @connections'
    permission :admin
    regex /^(\S+)\s+(.+)$/

    call do |m, name, string|
      p = plugin!(name)

      if p
        begin
          "#{p.instance_eval string}"
        rescue Exception
          "#{$!.message}\n#{$!.inspect}"
        end
      else
        "#{name}: Plugin not found"
      end
    end
  end

  # TODO: Re-implement command definitions
end
