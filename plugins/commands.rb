class Commands
  attr_accessor :cmds, :cc
  
  def initialize(sender, s={})
    @delegate = sender
    @cmds = Hash.new
    
    @cc = s['cc'] if s.has_key?('cc')
    @cc = '.' if @cc == nil
    
    sender.instances.each{ |key, instance| plugin_loaded(key, instance) }
  end
  
  def settings
    { 'cc' => @cc }
  end
  
  def self.wizard
    {
      'cc' => { 'help' => 'Control command, commands send to zmb must be prefixed with this.', 'default' => '.' },
    }
  end
  
  def event(sender, e)
    return if not e.message?
    
    if e.message[0, @cc.length] == @cc then
      line = e.message[@cc.length..-1].clone
    elsif e.private? then
      line = e.message.clone
    end
    
    # Encode escaped quotation marks
    line.gsub!(/\\"|\\'/) { |m| m =~ /^\\"$/ ? "\000d\000" : "\000s\000" }
    
    # Encode pipes inside quotation marks
    line.gsub!(/"\w*\|\w*"/) { |m| m.sub('|', "\000p\000") }
    
    # Check there are a even amount of "" and ''
    if ((line.count("'") % 2) == 1) and ((line.count('""') % 2) == 1) then
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
      args.each do |arg|
        arg.sub!("\000d\000", '"')
        arg.sub!("\000s\000", "'")
        arg.sub!("\000p\000", '|')
      end
      
      cmd = args.delete_at(0)
      args << input if input
      input = execute(cmd, e, args)
    end
    
    e.reply(input) if input
  end
  
  def execute(cmd, e, args)
    return if not @cmds.has_key?(cmd)
    
    c = @cmds[cmd]
    
    if c[2] == 0 then
      args = Array.new
    elsif args.size > c[2]
      a = args.first c[2]-1 # Take one under amount of commands
      a << args[c[2]-1..-1].join(' ')
      args = a
    end
    
    # User permissions
    if (kwargs = c.at(3)) and kwargs.has_key?(:permission) then
      if not e.respond_to?('user')
        return 'user module not loaded'
      elsif kwargs[:permission] == 'authenticated' then
        return 'permission denied' if not e.user.authenticated?
      elsif not e.user.permission?(kwargs[:permission])
        return 'permission denied'
      end
    end
    
    begin
      c[0].send(c[1], e, *args)
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
        v = [v] if v.class != Array
        v.insert(0, instance)
        v << 1 if v.size == 2 # add default command amount
        @cmds[k] = v
      end
    end
  end
  
  def plugin_unloaded(key, instance)
    @cmds = @cmds.reject{ |k,v| v[0] == instance }
  end
  
  def split_seperators(data)
    if data.include?("\n") then
      data.split("\n").map{ |arg| arg.strip }
    elsif data.include?(',') then
      data.split(',').map{ |arg| arg.strip }
    elsif data.include?(' ') then
      data.split(' ')
    else
      data
    end
  end
  
  def commands
    {
      'help' => :help,
      'instance' => [:instance_command, 1, { :help => 'List all commands availible for a instance.'}],
      'which' => [:which, 1, { :help => 'Find which plugin handles a command' }],
      'cc' => [:control_command, 1, { :permission => 'admin' }],
      'eval' => [:evaluate, 1, { :permission => 'admin' }],
      'count' => :count,
      'grep' => [:grep, 2],
      'not' => [:not_command, 2],
      'tail' => :tail,
      'echo' => :echo,
      'reverse' => :reverse,
    }
  end
  
  def help(e, command=nil)
    if command then
      h = []
      
      if @cmds.has_key?(command) and (kwargs = @cmds[command].at(3)).respond_to?('has_key?') then
        h << "#{command}: #{kwargs[:help]}" if kwargs.has_key?(:help)
        h << "Usage: #{command} #{kwargs[:usage]}" if kwargs.has_key?(:usage)
        h << "Example: #{command} #{kwargs[:example]}" if kwargs.has_key?(:example)
      end
      
      if h.size == 0 then
        'Command not found or no help availible for the command.'
      else
        h.join("\n")
      end
    else
      cmds = @cmds.reject{ |k,v| ((kwargs = v.at(3)) and kwargs.has_key?(:permission)) and not e.user.permission?(kwargs[:permission]) }
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
      c = @cmds[command][0]
      if c.respond_to?('instance') and c.plugin != c.instance then
        "#{c.plugin} (#{c.instance})"
      else
        c.plugin
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
    "#{eval string}"
  end
  
  def count(e, data)
    "#{split_seperators(data).size}"
  end
  
  def grep(e, search, data)
    split_seperators(data).reject{ |d| not d.include?(search) }.join(', ')
  end
  
  def not_command(e, search, data)
    split_seperators(data).reject{ |d| d.include?(search) }.join(', ')
  end
  
  def tail(e, data)
    split_seperators(data).reverse[0..2].join(', ')
  end
  
  def echo(e, data)
    "#{data}"
  end
  
  def reverse(e, data)
    data.reverse
  end
end

Plugin.define do
  name "commands"
  description "This plugin is needed for other plugins to function properly."
  object Commands
end
