class AutoVoice
  def initialize(sender, s)
    @settings = s
    @settings['noperm'] = true unless @settings.has_key?('noperm')
  end
  
  def event(sender, e)
    if e.command == 'join' and e.respond_to?('user') then
      if @settings['noperm'] or e.user.permission?('autovoice') then
        e.delegate.write "MODE #{e.channel} +v #{e.name}"
      end
    end
  end
  
  def commands
    {
      'autovoice' => [:autovoice, 0, {
        :permission => 'admin',
        :help => 'Toggle the permission setting for autovoice'
      }]
    }
  end
  
  def autovoice(e)
    @settings['noperm'] = (not @settings['noperm'])
    if @settings['noperm'] then
      "No permissions are required to be autovoiced"
    else
      "The permission `autovoice` is required to be autovoiced"
    end
  end
end

Plugin.define do
  name 'autovoice'
  object AutoVoice
end
