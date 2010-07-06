class Alias
  attr_accessor :aliases
  
  def initialize(sender, settings)
    @aliases = settings['aliases'] if settings.has_key?('aliases')
    @aliases = Hash.new if not @aliases
  end
  
  def settings
    { 'aliases' => @aliases }
  end
  
  def commands
    {
      'alias' => [:add, 2, {
        :permission => 'admin',
        :help => 'Create a alias',
        :example => 'hello? .echo Hello!' }],
      'unalias' => [:del, 1, {
        :permission => 'admin',
        :help => 'Remove a alias',
        :usage => 'hello?' }],
      'aliases' => [:aliases, 0, {
        :permission => 'admin',
        :help => 'List all aliases' }],
    }
  end
  
  def add(e, a, command)
    @aliases[a] = command
    "#{a} aliased"
  end
  
  def del(e, command)
    @aliases.delete(command)
    "#{command} deleted"
  end
  
  def aliases(e)
    @aliases.keys.join(", ")
  end
  
  def pre_event(sender, e)
    if e.message? then
      @aliases.each{ |a, c| e.message.sub!(a, c) if e.message =~ /^#{a}/ }
    end
  end
end

Plugin.define do
  name 'alias'
  description 'Alias a command as another command'
  object Alias
end
