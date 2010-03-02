require 'zmb/commands'

class Commands
  attr_accessor :cmds, :cc
  
  def initialize(sender, settings={})
    @delegate = sender
    @cmds = Hash.new
    
    @cc = settings['cc'] if settings.has_key?('cc')
    @cc = '!' if @cc == nil
    
    @cmds.merge!(commands)
    
    sender.post('commands').each do |command|
      @cmds.merge!(command)
    end
  end
  
  def to_json(*a)
    { 'cc' => @cc, 'plugin' => 'commands' }.to_json(*a)
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
      
      if @cmds.has_key?(cmd) then
        args << input if input
        input = @cmds[cmd].run(e, args)
      end
    end
    
    e.reply(input) if input
  end
  
  def plugin_loaded(key, instance)
    @cmds.merge!(instance.commands) if instance.respond_to?('commands')
  end
  
  def plugin_unloaded(key, instance)
    instance.commands.each{|command, cmd| @cmds.delete(command)} if instance.respond_to?('commands')
  end
  
  def split_seperators(data)
    if data.include?("\n") then
      data.split("\n")
    elsif data.include?(',') then
      data.split(',')
    elsif data.include?(' ') then
      data.split(' ')
    else
      data
    end
  end
  
  def commands
    {
      'help' => Command.new(self, :help),
      'instance' => Command.new(self, :instance, 1, 'List all commands availible for a instance.'),
      'cc' => PermCommand.new('admin', self, :control_command),
      'eval' => PermCommand.new('admin', self, :evaluate),
      'count' => Command.new(self, :count),
      'grep' => Command.new(self, :grep, 2),
      'not' => Command.new(self, :not_command, 2),
      'tail' => Command.new(self, :tail),
      'echo' => Command.new(self, :echo),
    }
  end
  
  def help(e, command=nil)
    if command then
      if @cmds.has_key?(command) and @cmds[command].help? then
        "#{command}: #{@cmds[command].help}"
      else
        'Command not found or no help availible for the command.'
      end
    else
      @cmds.keys.join(', ')
    end
  end
  
  def instance(e, inst)
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
  
  def control_command(e, cc=nil)
    if cc then
      @cc = cc
    else
      @cc = '!'
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
end

Plugin.define do
  name "commands"
  description "This plugin is needed for other plugins to function properly."
  object Commands
end
