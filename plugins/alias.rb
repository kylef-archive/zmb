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
      'alias' => [:add, 2, { :permission => 'admin' }],
      'unalias' => [:del, 1, { :permission => 'admin' }],
      'aliases' => [:aliases, 0, { :permission => 'admin' }]
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
  object Alias
end
