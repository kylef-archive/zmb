class Magicword
  attr_accessor :words
  
  def initialize(sender, settings={})
    @words = Array.new
  end
  
  def event(sender, e)
    return if not e.message? or e.private?
    
    
  end
  
  def commands
    require 'zmb/commands'
    {
      'set-word' => Command.new(self, :set, 1, 'Set the magic word.'),
      'give-word' => Command.new(self, :give, 1, 'Donate the ownership of a word to someone else.'),
      'word?' => Command.new(self, :word, 0, 'Check if the magic word is set, and who set it.'),
      
      'addwordnotf' => PermCommand.new('admin', self, :addwordnotf),
      'lswordnotf' => PermCommand.new('admin', self, :addwordnotf),
      'remwordnotf' => PermCommand.new('admin', self, :addwordnotf),
    }
  end
  
  def set(e, word=nil)
    if e.respond_to?('user') and e.user.permission?('magicword') then
      @magicword = word
      "Magicword set to #{word}"
    else
      'permission denied'
    end
  end
  
  def give(e, search)
    e.user.deny('magicword')
  end
  
  def word(e)
    
  end
end

Plugin.define do
  name "magicword"
  description "irc connections"
  object Magicword
end
