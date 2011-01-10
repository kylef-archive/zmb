class Commands <Plugin
  name :commands
  description  "This plugin is needed for other plugins to function properly."

  attr_accessor :cmds, :cc, :definitions
  
  def initialize(sender, s={})
    super

    @delegate = sender
    @cmds = Hash.new
    @definitions = Hash.new
    
    @cc = s['cc'] if s.has_key?('cc')
    @cc = '.' if @cc == nil
    @definitions = s['definitions'] if s.has_key?('definitions')
    
    sender.plugins.each{ |p| plugin_loaded(p.class.name, p) }
    
    @definitions.each do |k,v|
      @cmds[k] = {
        :args => v[0],
        :proc => (eval v[1])
      }
    end

    plugin_loaded(self.class.name, self)
  end
  
  def settings
    { 'cc' => @cc, 'definitions' => @definitions }
  end
  
  def self.wizard
    {
      'cc' => { 'help' => 'Control command, commands send to zmb must be prefixed with this.', 'default' => '.' },
    }
  end
  
  def escape
    {
      '"' => "\000d\000",
      "'" => "\000s\000",
      '|' => "\000p\000",
    }
  end

  def irc_message(connection, message)
    if message[0, @cc.length] == @cc then
      line = message[@cc.length..-1].clone
    elsif message =~ /^#{connection.nick}(:|,) (.+)/
      line = $2
    elsif message.private? then
      line = message
    else
      return
    end

    line.sub!('{time}', Time.now.strftime('%H:%M:%S'))
    line.sub!('{day}', Time.now.strftime('%d'))
    line.sub!('{weekday}', Time.now.strftime('%A'))
    line.sub!('{timezone}', Time.now.strftime('%Z'))
    line.sub!('{month}', Time.now.strftime('%B'))
    line.sub!('{year}', Time.now.strftime('%Y'))
    line.sub!('{username}', message.opts[:user].username)
    line.sub!('{points}', "#{message.opts[:bank].balance}") if message.opts.has_key?(:bank)
    line.sub!('{channel}', message.channel.to_s) unless message.channel.nil?
    line.sub!('{nick}', message.user.nick)
    line.sub!('{userhost}', message.user.userhost)
    line.sub!('{rand}', String.random)
    
    # Encode escaped quotation marks and pipes
    escape.each{ |k,v| line.gsub!("\\" + k, v) }
    
    # Check there are a even amount of "" and ''
    if ((line.count("'") % 2) == 1) and ((line.count('"') % 2) == 1) then
      return message.reply('Incorrect amount of quotation marks\'s')
    end
    
    # Split the commands up
    commands = line.split('|')
    input = nil
    
    commands.each do |command|
      command = command.reverse.chomp.reverse
      
      # Split strings by quotation marks and spaces
      args = command.split(/"([^"]*)"|'([^']*)'|\s/).reject{ |x| x.empty? }
      
      # Decode escape quotation marks and pipes inside the args
      args.each{ |arg| escape.each{ |k,v| arg.gsub!(v, k) } }
      
      cmd = args.delete_at(0)
      args << input if input
      input = execute(cmd, message, args)
    end
    
    message.reply(input) if input
  end
  
  def execute(cmd, message, args=[])
    return "#{cmd}: command not found" if not @cmds.has_key?(cmd)
    
    c = @cmds[cmd]
    
    if c[:args] == 0 then
      args = Array.new
    elsif args.size > c[:args]
      a = args.first c[:args]-1 # Take one under amount of commands
      a << args[c[:args]-1..-1].join(' ')
      args = a
    end
    
    # User permissions
    if c.has_key?(:permission) then
      if not message.opts.has_key?(:user)
        return 'user module not loaded'
      end

      if c[:permission] == 'authenticated' then
        return 'permission denied' if not message.opts[:user].authenticated?
      elsif not message.opts[:user].permission?(c[:permission])
        return 'permission denied'
      end
    end
    
    begin
      if c.has_key?(:instance) and c.has_key?(:symbol) then
        c[:instance].send(c[:symbol], message, *args)
      elsif c.has_key?(:proc) then
        c[:proc].call(message, *args)
      else
        delegate("Bad command definition (#{cmd})")
        "Bad command definition"
      end
    rescue ArgumentError
      'incorrect arguments'
    rescue Exception
      zmb.debug(c.has_key?(:instance) ? c[:instance] : self, "Command #{cmd} failed", $!)
      
      if message.opts.has_key?(:user) and message.opts[:user].admin? and message.private? then
        "#{$!.message}\n#{$!.inspect}\n#{$!.backtrace[0..2].join("\n")}"
      else
        'command failed'
      end
    end
  end
  
  def plugin_loaded(plugin_name, p)
    if p.respond_to?('commands') then
      p.commands.each do |k,v|
        @cmds[k] = {
          :instance => p,
          :args => 1
        }
        
        if v.class == Hash then
          @cmds[k].merge(v)
        else
          v = [v] if v.class != Array
          v.each do |item|
            @cmds[k][:args] = item if item.class == Fixnum
            @cmds[k].merge!(item) if item.class == Hash
            @cmds[k][:symbol] = item if item.class == Symbol
            @cmds[k][:proc] = item if item.class == Proc
          end
        end
        
        @cmds[k][:args] = @cmds[k][:usage].split(' ').count if @cmds[k].has_key?(:usage)
      end
    end
  end
  
  def plugin_unloaded(plugin_name, p)
    @cmds = @cmds.reject{ |k,v| v[:instance] == p }
  end
  
  def commands
    {
      'help' => :help,
      'pcommands' => [:plugin_commands, { :help => 'List all commands availible for a plugin.'}],
      'which' => [:which, { :help => 'Find which plugin handles a command' }],
      'cc' => [:control_command, {
        :permission => 'admin',
        :help => 'Set the control character for commands' }],
      'eval' => [:evaluate, {
        :permission => 'admin',
        :help => 'Evaluate ruby code' }],
      'peval' => [:plugin_evaluate, 2, {
        :permission => 'admin',
        :help => 'Evaluate ruby on on a plugin',
        :usage => 'commands @cc' }],
      'count' => [lambda { |e, data| "#{data.split_seperators.size}" }, {
        :help => 'Count the amount of items in a list' } ],
      'grep' => [:grep, 2, { :help => 'print lines matching a pattern' } ],
      'not' => [:not_command, 2, { :help => 'Opposite to grep' } ],
      'tail' => [:tail, { :help => 'List the last three items in a list' }],
      'echo' => [:echo, { :example => 'Hello, {username}' }],
      'reverse' => lambda { |e, data| data.reverse },
      'first' => lambda { |e, data| data.split_seperators.first },
      'last' => lambda { |e, data| data.split_seperators.last },
      'sub' => [:sub, {
        :help => 'Replace all occurances of a pattern',
        :usage => 'pattern replacement data',
        :example => 'l * Hello World!' }],
      'tr' => [:tr, {
        :help => 'Returns a copy of str with the characters in from_str replaced by the corresponding characters in to_str',
        :usage => 'from_str to_str data',
        :example => 'aeiou * hello' }],
      'downcase' => lambda { |e, data| data.downcase },
      'upcase' => lambda { |e, data| data.upcase },
      'swapcase' => lambda { |e, data| data.swapcase },
      'capitalize' => lambda { |e, data| data.capitalize },
      'define' => [:define, {
        :permission => 'admin',
        :help => 'Dynamically define a command',
        :usage => 'command arguments block',
        :example => 'ping nil "pong"'
      }],
      'undefine' => [:undefine, {
        :permission => 'admin',
        :help => 'Undefine a command',
        :usage => 'command',
        :example => 'ping'
      }]
    }
  end
  
  def help(e, command=nil)
    if command then
      h = []
      
      if @cmds.has_key?(command) then
        h << "#{command}: #{@cmds[command][:help]}" if @cmds[command].has_key?(:help)
        h << "Usage: #{command} #{@cmds[command][:usage]}" if @cmds[command].has_key?(:usage)
        h << "Example: #{command} #{@cmds[command][:example]}" if @cmds[command].has_key?(:example)
      end
      
      if h.size == 0 then
        'Command not found or no help availible for the command.'
      else
        h.join("\n")
      end
    else
      cmds = @cmds.reject{ |k,v| (v.has_key?(:permission)) and not e.user.permission?(v[:permission]) }
      cmds.keys.join(', ')
    end
  end
  
  def plugin_commands(e, plugin_name)
    if p = @delegate.plugin(plugin_name.to_sym)
      if p.respond_to?('commands') then
        p.commands.keys.join(', ')
      else
        "No commands availible for #{plugin_name}"
      end 
    else
      "No plugin found for #{plugin_name}"
    end
  end
  
  def which(e, command)
    if @cmds.has_key?(command) then
      if @cmds[command].has_key?(:instance)
        cmds[command][:instance].plugin
      else
        "No plugin for command #{command}"
      end
    else
      "#{command}: Command not found"
    end
  end
  
  def control_command(e, cc=nil)
    if cc then
      @cc = cc
    else
      @cc = '.'
    end
    
    "Control command set to #{@cc}"
  end
  
  def evaluate(e, string)
    begin
      "#{eval string}"
    rescue Exception
      "#{$!.message}\n#{$!.inspect}"
    end
  end
  
  def plugin_evaluate(e, plugin_name, string)
    begin
      if p = @delegate.plugin(plugin_name.to_sym) then
        "#{p.instance_eval string}"
      else
        "#{plugin_name}: No such plugin"
      end
    rescue Exception
      "#{$!.message}\n#{$!.inspect}"
    end
  end
  
  def grep(e, search, data)
    data.split_seperators.reject{ |d| not d.include?(search) }.join(', ')
  end
  
  def not_command(e, search, data)
    data.split_seperators.reject{ |d| d.include?(search) }.join(', ')
  end
  
  def tail(e, data)
    data.split_seperators.reverse[0..2].join(', ')
  end
  
  def echo(e, data)
    "#{data}"
  end
  
  def sub(e, pattern, replacement, data)
    data.gsub(pattern, replacement)
  end
  
  def tr(e, from_str, to_str, data)
    data.tr(from_str, to_str)
  end
  
  def define(e, command, arguments, block)
    arguments = arguments.split_seperators
    arguments = [] if arguments.include?('nil') or arguments.include?('none')
    arguments.insert(0, 'e')
    
    @cmds[command] = {
      :args => arguments.count - 1,
      :proc => (eval "lambda {|#{arguments.join(',')}| #{block}}")
    }
    
    @definitions[command] = [arguments.count-1, "lambda {|#{arguments.join(',')}| #{block}}"]
    
    "#{command} has been defined"
  end
  
  def undefine(e, command)
    @cmds.delete(command)
    @definitions.delete(command)
    
    "#{command} removed"
  end
end
