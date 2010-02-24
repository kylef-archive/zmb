class Relay
  attr_accessor :relays
  
  def initialize(sender, settings={})
    @relays = settings['relays'] if settings.has_key?('relays')
    @relays = Hash.new if not @relays
  end
  
  def to_json(*a)
    { 'relays' => @relays, 'plugin' => 'relay' }.to_json(*a)
  end
  
  def event(sender, e)
    # Does the sender have a relay?
  end
  
  def commands
    require 'zmb/commands'
    {
      'relays' => PermCommand.new('admin', self, :relays_command, 0, 'Show all relays'),
      'relay-add' => PermCommand.new('admin', self, :add_command, 2, 'Add a relay'),
      'relay-del' => PermCommand.new('admin', self, :del_command, 1, 'Delete a relay'),
    }
  end
  
  def relays_command(e)
    if @relays.count < 1 then
      "no relays"
    else
      @relays.each{ |relay, location| "#{relay} > #{location}"}.join("\n")
    end
  end
  
  def add_command(e, relay, location)
    if relay.include? ':' and location.include? ':' then
      if @relays.has_key?(relay) then
        "relays must be unique"
      else
        @relays[relay] = location
        "relay setip #{relay} => #{location}"
      end
    else
      "relays must be in the format: plugin:location, example (efnet:\#zmb)"
    end
  end
  
  def del_command(e, relay)
    if @plugins.has_key?(relay) then
      @plugins.delete(relay)
      "#{relay}: relay deleted"
    else
      "no such relay"
    end
  end
end

Plugin.define do
  name "relay"
  description "This plugin allows you to relay messages from one channel/server to another."
  object Relay
end