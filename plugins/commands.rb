class Commands
  attr_accessor :cmds, :cc, :definitions
  
  def initialize(sender, s={})
    @delegate = sender
    @cmds = Hash.new
    @definitions = Hash.new
    
    @cc = s['cc'] if s.has_key?('cc')
    @cc = '.' if @cc == nil
    @definitions = s['definitions'] if s.has_key?('definitions')
    
    sender.instances.each{ |key, instance| plugin_loaded(key, instance) }
    
    @definitions.each do |k,v|
      @cmds[k] = {
        :args => v[0],
        :proc => (eval v[1])
      }
    end
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
  
  def event(sender, e)
    return if not e.message?
    
    if e.message[0, @cc.length] == @cc then
      line = e.message[@cc.length..-1].clone
    elsif e.delegate.respond_to?('nick') and e.message[0, (e.delegate.nick.length+2)] == (e.delegate.nick + ': ') then
      line = e.message[(e.delegate.nick.length+2)..-1].clone
    elsif e.private? then
      line = e.message.clone
    else
      return
    end
    
    return if e.name[0..0] == '*'
    
    line.sub!('{time}', Time.now.strftime('%H:%M:%S'))
    line.sub!('{day}', Time.now.strftime('%d'))
    line.sub!('{weekday}', Time.now.strftime('%A'))
    line.sub!('{timezone}', Time.now.strftime('%Z'))
    line.sub!('{month}', Time.now.strftime('%B'))
    line.sub!('{year}', Time.now.strftime('%Y'))
    line.sub!('{username}', e.user.username) if e.respond_to?('user') and e.user.respond_to?('username')
    line.sub!('{points}', "#{e.bank.balance}") if e.respond_to?('bank') and e.bank.respond_to?('balance')
    line.sub!('{channel}', e.channel) if e.respond_to?('channel')
    line.sub!('{name}', e.name) if e.respond_to?('name')
    line.sub!('{userhost}', e.userhost) if e.respond_to?('userhost')
    line.sub!('{rand}', String.random)
    
    # Encode escaped quotation marks and pipes
    escape.each{ |k,v| line.gsub!("\\" + k, v) }
    
    # Check there are a even amount of "" and ''
    if ((line.count("'") % 2) == 1) and ((line.count('"') % 2) == 1) then
      return e.reply('Incorrect amount of quotation marks\'s')
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
      input = execute(cmd, e, args)
    end
    
    e.reply(input) if input
  end
  
  def execute(cmd, e, args=[])
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
      if not e.respond_to?('user')
        return 'user module not loaded'
      elsif c[:permission] == 'authenticated' then
        return 'permission denied' if not e.user.authenticated?
      elsif not e.user.permission?(c[:permission])
        return 'permission denied'
      end
    end
    
    begin
      if c.has_key?(:instance) and c.has_key?(:symbol) then
        c[:instance].send(c[:symbol], e, *args)
      elsif c.has_key?(:proc) then
        c[:proc].call(e, *args)
      else
        "Bad command definition"
      end
    rescue ArgumentError
      'incorrect arguments'
    rescue Exception
      if e.respond_to?('user') and e.user.admin? and e.private? then
        "#{$!.message}\n#{$!.inspect}\n#{$!.backtrace[0..2].join("\n")}"
      else
        'command failed'
      end
    end
  end
  
  def plugin_loaded(key, instance)
    if instance.respond_to?('commands') then
      instance.commands.each do |k,v|
        @cmds[k] = {
          :instance => instance,
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
      end
    end
  end
  
  def plugin_unloaded(key, instance)
    @cmds = @cmds.reject{ |k,v| v[:instance] == instance }
  end
  
  def commands
    {
      'help' => :help,
      'instance' => [:instance_command, 1, { :help => 'List all commands availible for a instance.'}],
      'which' => [:which, 1, { :help => 'Find which plugin handles a command' }],
      'cc' => [:control_command, 1, { :permission => 'admin' }],
      'eval' => [:evaluate, 1, { :permission => 'admin' }],
      'ieval' => [:instance_evaluate, 2, { :permission => 'admin' }],
      'count' => lambda { |e, data| "#{data.split_seperators.size}" },
      'grep' => [:grep, 2],
      'not' => [:not_command, 2],
      'tail' => :tail,
      'echo' => [:echo, 1, { :example => 'Hello, {username}' }],
      'reverse' => lambda { |e, data| data.reverse },
      'first' => lambda { |e, data| data.split_seperators.first },
      'last' => lambda { |e, data| data.split_seperators.last },
      'sub' => [:sub, 3, {
        :help => 'Replace all occurances of a pattern',
        :usage => 'pattern replacement data',
        :example => 'l * Hello World!' }],
      'tr' => [:tr, 3, {
        :help => 'Returns a copy of str with the characters in from_str replaced by the corresponding characters in to_str',
        :usage => 'from_str to_str data',
        :example => 'aeiou * hello' }],
      'downcase' => lambda { |e, data| data.downcase },
      'upcase' => lambda { |e, data| data.upcase },
      'swapcase' => lambda { |e, data| data.swapcase },
      'capitalize' => lambda { |e, data| data.capitalize },
      'define' => [:define, 3, {
        :permission => 'admin',
        :help => 'Dynamically define a command',
        :usage => 'command arguments block',
        :example => 'ping nil \"pong\"'
      }],
      'undefine' => [:undefine, 1, {
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
  
  def instance_command(e, inst)
    if @delegate.instances.has_key?(inst) then
      if @delegate.instances[inst].respond_to?('commands') then
        @delegate.instances[inst].commands.keys.join(', ')
      else
        "No commands availible for #{inst}"
      end 
    else
      "No instance found for #{inst}"
    end
  end
  
  def which(e, command)
    if @cmds.has_key?(command) then
      if @cmds[command].has_key?(:instance) and @cmds[command][:instance].plugin != @cmds[command][:instance].instance then
        "#{@cmds[command][:instance].plugin} (#{@cmds[command][:instance].instance})"
      else
        @cmds[command][:instance].plugin
      end
    else
      'command not found'
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
  
  def instance_evaluate(e, inst, string)
    begin
      if @delegate.instances.has_key?(inst) then
        "#{@delegate.instances[inst].instance_eval string}"
      else
        "#{inst}: No such instance"
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

Plugin.define do
  name "commands"
  description "This plugin is needed for other plugins to function properly."
  object Commands
end
