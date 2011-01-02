class Usermodes <Plugin
  name :usermodes
  description 'Auto opping, voicing users in a channel'

  def initialize(sender, s)
    @usermodes = Hash.new
    @usermodes = s['usermodes'] if s.has_key?('usermodes')
  end
  
  def settings
    { 'usermodes' => @usermodes }
  end
  
  def add(instance, channel, username, mode)
    k = instance + ':' + channel
    @usermodes[k] = Hash.new if not @usermodes.has_key?(k)
    @usermodes[k][username] = Array.new if not @usermodes[k].has_key?(username)
    @usermodes[k][username] << mode
  end
  
  def remove(instance, channel, username=nil, mode=nil)
    k = instance + ':' + channel
    @usermodes.delete(k) if @usermodes.has_key?(k) and username == nil
    
    if @usermodes.has_key?(k) and @usermodes[k].has_key?(username) then
      @usermodes[k][username].delete(mode)
      @usermodes[k].delete(username) if not mode or @usermodes[k][username].empty?
      @usermodes.delete(k) if @usermodes[k].empty?
    end
  end
  
  def event(sender, e)
    if e.command == 'join' and e.respond_to?('user') and not e.user.anonymous? then
      if @usermodes.has_key?(k = e.delegate.instance + ':' + e.channel) then
        if @usermodes[k].has_key?(e.user.username) then
          @usermodes[k][e.user.username].each{ |mode| e.delegate.write "MODE #{e.channel} +#{mode} #{e.name}" }
        end
      end
    end
  end
  
  def commands
    {
      'usermode-add' => [:usermode_add, {
        :permission => 'admin',
        :help => 'Apply a usermode to a user when they join a channel',
        :usage => 'instance channel user mode',
        :example => 'efnet #zmb zynox o' }],
      'usermode-del' => [:usermode_del, {
        :permission => 'admin',
        :help => 'Delete a usermode',
        :usage => 'instance channel user mode',
        :example => 'efnet #zmb zynox o' }],
      'usermodes' => [:usermodes, {
        :permission => 'admin',
        :help => 'List all usermodes for a channel',
        :usage => 'instance channel',
        :example => 'efnet #zmb' }],
      'usermodes-ls' => [:usermodes_ls, 0, {
        :permission => 'admin',
        :help => 'List all channels usermodes are applied to' }],
      'enforce' => [:enforce, 0, {
        :permission => 'authenticated',
        :help => 'Enforce all your usermodes in the current channel.' }],
      'vanish' => [:vanish, 0, {
        :permission => 'authenticated',
        :help => 'Remove all your usermodes in the current channel.' }],
    }
  end
  
  def usermode_add(e, *args)
    add(*args)
    "usermode added"
  end
  
  def usermode_del(e, *args)
    remove(*args)
    "usermode deleted"
  end
  
  def usermodes(e, instance, channel)
    k = instance + ':' + channel
    if @usermodes.has_key?(k) then
      @usermodes[k].map{ |k,v| "#{k} +#{v.join('')}" }.join("\n")
    else
      'no usermodes found for instance/channel'
    end
  end
  
  def usermodes_ls(e)
    @usermodes.keys.map{ |k| k.split(':', 2) }.map{ |i,c| "#{i} - #{c}" }.join("\n")
  end
  
  def enforce(e)
    if @usermodes.has_key?(k = e.delegate.instance + ':' + e.channel) and e.user.authenticated? and @usermodes[k].has_key?(e.user.username) then
      @usermodes[k][e.user.username].each{ |mode| e.delegate.write "MODE #{e.channel} +#{mode} #{e.name}" }
    end
    
    "usermodes enforced"
  end
  
  def vanish(e)
    if @usermodes.has_key?(k = e.delegate.instance + ':' + e.channel) and e.user.authenticated? and @usermodes[k].has_key?(e.user.username) then
      @usermodes[k][e.user.username].each{ |mode| e.delegate.write "MODE #{e.channel} -#{mode} #{e.name}" }
    end
    
    "usermodes vanished"
  end
end
