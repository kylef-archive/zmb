class Event
  attr_accessor :user, :users
end

class User
  require 'digest/sha1'
  require 'time'
  
  attr_accessor :settings, :users
  
  def initialize(s)
    @settings = defaults.merge(s)
    @settings['seen'] = Time.parse(@settings['seen']) if @settings['seen'].class == String
  end
  
  def self.networks
    {
      'delicious' => ['Delicious', 'http://delicious.com/%s'],
      'digg' => ['Digg.com', 'http://digg.com/users/%s'],
      'django' => ['Django People', 'http://djangopeople.net/%s'],
      'facebook' => ['Facebook', 'http://www.facebook.com/profile.php?id=%s'],
      'flickr' => ['Flickr', 'http://www.flickr.com/photos/%s/'],
      'github' => ['GitHub', 'http://github.com/%s'],
      'pandora' => ['Pandora', 'http://pandora.com/people/%s'],
      'technorati' => ['Technorati', 'http://technorati.com/people/technorati/%s'],
      'tumblr' => ['Tumblr', 'http://%s.tumblr.com'],
      'twitter' => ['Twitter', 'http://twitter.com/%s'],
      'lastfm' => ['Last.fm', 'http://www.last.fm/user/%s'],
      'xfire' => ['Xfire', 'http://www.xfire.com/profile/%s/'],
      'ustream' => ['Ustream.TV', 'http://www.ustream.tv/%s'],
      'youtube' => ['YouTube', 'http://www.youtube.com/user/%s'],
      'steam' => ['Steam', 'http://steamcommunity.com/id/%s/'],
      
      'netforce' => ['Net-Force', 'http://www.net-force.nl/members/view/%s/'],
      'hts' => ['Hack This Site!', 'http://www.hackthissite.org/user/view/%s/'],
    }
  end
  
  def defaults
    {
      'username' => 'username',
      'password' => nil,
      'email' => nil,
      'userhosts' => [],
      'permissions' => [],
      'seen' => Time.now,
      'location' => '',
      'active' => true,
      'networks' => Hash.new,
      'buffer' => [],
    }
  end
  
  def username
    @settings['username']
  end
  
  def raw_password=(new_password)
    @settings['password'] = new_password
  end
  
  def password=(new_password)
    @settings['password'] = Digest::SHA1.hexdigest(new_password)
  end
  
  def password?(check_password)
    @settings['password'] != nil and @settings['password'] == Digest::SHA1.hexdigest(check_password)
  end
  
  def email
    @settings['email']
  end
  
  def email=(e)
    @settings['email'] = e
  end
  
  def userhosts
    @settings['userhosts']
  end
  
  def permissions
    @settings['permissions']
  end
  
  def seen
    @settings['seen']
  end
  
  def location
    @settings['location']
  end
  
  def location=(l)
    @settings['location'] = l
  end
  
  def network?(n)
    @settings['networks'].has_key?(n)
  end
  
  def network(n)
    return nil if not self.class.networks.has_key?(n)
    self.class.networks[n][1].sub('%s', network!(n))
  end
  
  def network!(n)
    @settings['networks'][n]
  end
  
  def networks
    @settings['networks'].keys
  end
  
  def add_network(n, info)
    @settings['networks'][n] = info
  end
  
  def saw(e=nil)
    @settings['seen'] = Time.now
    
    if e then
      buffer.each do |message|
        e.delegate.message(e.name, message)
      end
      
      clear_buffer
    end
  end
  
  def activate
    @settings['active'] = true
  end
  
  def deactivate
    @settings['active'] = false
  end
  
  def to_s
    username
  end
  
  def concat(other_user)
    @permissions += other_user.permissions
    @userhosts += other_user.userhosts
  end
  
  def anonymous?
    false
  end
  
  def authenticated?
    true
  end
  
  def active?
    @settings['active']
  end
  
  def admin?
    permissions.include?('admin')
  end
  
  def permission?(permission)
    admin? or permissions.include?(permission)
  end
  
  def permit(permission)
    permissions << permission
  end
  
  def deny(permission)
    permissions.delete(permission)
  end
  
  def buffer
    @settings['buffer']
  end
  
  def clear_buffer
    @settings['buffer'] = []
  end
  
  def send(message)
    @settings['buffer'] << message
  end
end

class AnonymousUser
  def to_s
    'nobody'
  end
  
  def anonymous?
    true
  end
  
  def authenticated?
    false
  end
  
  def permission?(permission)
    false
  end
  
  def admin?
    false
  end
end

class Users
  attr_accessor :users, :user_defaults
  
  def initialize(sender, s={})
    @delegate = sender
    @users = Array.new
    @user_defaults = Hash.new
    @users = s['users'].map{ |user| User.new(user) } if s.has_key?('users')
    @user_defaults = s['user_defaults'] if s.has_key?('user_defaults')
  end
  
  def settings
    { 'users' => @users.map{ |u| u.settings }, 'user_defaults' => @user_defaults }
  end
  
  def user!(search, active=nil)
    if active == nil then
      @users.find{ |user| user.userhosts.include?(search) or user.username == search }
    else
      @users.find{ |user| (user.userhosts.include?(search) or user.username == search) and user.active? == active }
    end
  end
  
  def user(search, active=nil)
    user!(search, active) or AnonymousUser.new
  end
  
  def pre_event(sender, e)
    e.users = self
    e.user = user(e.userhost, true) if not e.user and e.respond_to?('userhost')
    e.user.saw(e) unless e.user.anonymous?
  end
  
  def commands
    {
      'activate' => [:activate, 1, { :help => 'Activate a user account' }],
      'deactivate' => [:deactivate, 1, { :help => 'Deactivate a user account' }],
      'meet' => [:meet, 1, { :help => 'Meet a user' }],
      'forget' => [:forget, 1, {
        :help => 'Forget about a user',
        :permission => 'authenticated' }],
      'permit' => [:permit, 2, {
        :permission => 'admin',
        :help => 'Add a permission to a user',
        :usage => '<user> <permission>',
        :example => 'zynox admin' }],
      'deny' => [:deny, 2, {
        :permission => 'admin',
        :help => 'Remove a permission from a user',
        :usage => '<user> <permission>',
        :example => 'zynox admin' }],
      'perms' => [:perms, 0, {
        :permission => 'authenticated',
        :help => 'List all the permissions you have' }],
      'group' => [:group, 1, {
        :permission => 'admin' }],
      'merge' => [:merge, 2, {
        :permission => 'admin',
        :help => 'Merge two users together, give user a the permissions and useragents of b and then delete b',
        :usage => 'user_a user_b'}],
      'password' => [:password, 1, {
        :permission => 'authenticated',
        :help => 'Set the password for your account',
        :usage => 'password' }],
      'login' => [:login, 2, {
        :help => 'Login to your account, adding your current userhost to your account.',
        :usage => 'username password' }],
      'logout' => [:logout, 0, {
        :permission => 'authenticated',
        :help => 'Logout from your account, this will remove your current userhost from your account.' }],
      'whoami' => [lambda { |e| "#{e.user}" }, 0, { :help => 'Who are you logged in as?' }],
      'userhosts' => [:userhosts, 0, {
        :permission => 'authenticated',
        :help => 'List all the userhosts associated with your account.' }],
      'adduserhost' => [:adduserhost, 1, {
        :permission => 'authenticated',
        :help => 'Add a userhost to your account.' }],
      'rmuserhost' => [:rmuserhost, 1, {
        :permission => 'authenticated',
        :help => 'Remove a userhost to your account.' }],
      'names' => [:names, 1, {
        :help => 'List all the users',
        :usage => '<search>' }],
      'seen' => [:seen, 1, {
        :help => 'When was a user last seen?',
        :usage => 'user' }],
      'sudo' => [:sudo, 2, {
        :permission => 'admin',
        :help => 'Execute a command as another user.',
        :usage => 'user command',
        :example => 'zynox whoami' }],
      'location' => [:location, 1, {
        :permission => 'authenticated',
        :help => 'Set your location' }],
      'email' => [:email, 1, {
        :permission => 'authenticated',
        :help => 'Set your email' }],
      'user-defaults' => [:user_defaults_command, 0],
      'user-default' => [:set_default, 2, {
        :permission => 'admin',
        :help => 'Set a user default',
        :usage => 'key value',
        :example => 'active false' }],
      'rm-user-default' => [:del_default, 1, {
        :permission => 'admin',
        :help => 'Remove a user default',
        :usage => 'key',
        :example => 'active' }],
      'network' => [:network, 2, {
        :permission => 'authenticated',
        :usage => 'lastfm zynox' }],
      'networks' => [:networks, 0, { :help => 'List all availible networks' }],
      'profile' => [:profile, 1, {
        :permission => 'authenticated' }],
      'message' => [:message, 2, { :permission => 'authenticated' }],
      'broadcast' => [:broadcast, {
        :permission => 'admin',
        :help => 'Broadcast a message to every user',
        :usage => 'message' }],
    }
  end
  
  def activate(e, username)
    if user = user!(username) then
      user.activate
      "#{username} active"
    else
      "#{username} does not exist"
    end
  end
  
  def deactivate(e, username)
    if user = user!(username) then
      user.deactivate
      "#{username} deactivated"
    else
      "#{username} does not exist"
    end
  end
  
  def meet(e, username=nil)
    username = e.name if not e.user.admin?
    
    if username == 'nobody' then
      "nobody is a excluded name"
    elsif not user!(username) then
      @users << user = User.new(@user_defaults.merge({'username' => username}))
      user.userhosts << e.userhost if not e.user.admin? and e.respond_to?('userhost')
      "Hello #{user}"
    else
      "You already have an account #{e.user}"
    end
  end
  
  def forget(e, username=nil)
    if e.user.admin? and username then
      "user #{@users.delete(user(username))} deleted"
    else
      "user #{@users.delete(e.user)} deleted"
    end
  end
  
  def permit(e, username, permission)
    if user = user!(username) then
      user.permit(permission)
      "permission added"
    else
      "#{username} does not exist"
    end
  end
  
  def deny(e, username, permission)
    if user = user!(username) then
      user.deny(permission)
      'permission removed'
    else
      "#{username} does not exist"
    end
  end
  
  def perms(e)
    e.user.permissions.empty? ? "#{e.user} has no permissions" : e.user.permissions.join(', ')
  end
  
  def group(e, group)
    @users.reject{ |user| not user.permissions.include?(group) }.join(', ')
  end
  
  def merge(e, username, other_username)
    user = user!(username)
    other_user = user!(other_username)
    
    if user and other_user then
      user.concat other_user 
      @users.delete other_user
      "#{other_user} now merged into #{user}"
    else
      'User(s) do not exist'
    end
  end
  
  def password(e, password)
    e.user.password = password
    "#{e.user} password has been set to #{password}"
  end
  
  def login(e, username, password)
    user = user!(username)
    
    if user and user.password?(password) then
      user.userhosts << e.userhost
      "#{e.userhost} added to your account #{user}"
    else
      'user and/or password is incorrect'
    end
  end
  
  def logout(e)
    e.user.userhosts.delete(e.userhost)
    "userhost #{e.userhost} removed from your account."
  end
  
  def userhosts(e)
    e.user.userhosts.empty? ?  "#{e.user} has no userhosts" : e.user.userhosts.join(', ')
  end
  
  def adduserhost(e, userhost)
    e.user.userhosts << userhost
    "#{userhost} added to #{e.user}"
  end
  
  def rmuserhost(e, userhost)
    if e.user.userhosts.delete(userhost) then
      "#{userhost} deleted from #{e.user}"
    else
      "#{e.user} doesn't have #{userhost}"
    end
  end
  
  def names(e, search=nil)
    users = @users.map{ |user| user.username }
    users = users.grep(/#{search}/i) if search
    
    if users.empty? then
      "no users found"
    else
      users.join(', ')
    end
  end
  
  def seen(e, username)
    if username == e.user.username then
      "Are you looking for yourself?"
    elsif user = user!(username) and user.seen then
      "#{username} last seen #{user.seen.since_words}"
    else
      "#{username} has never been seen"
    end
  end
  
  def sudo(e, username, command=nil)
    user = user(username)
    
    if command then
      new_event = e.clone
      new_event.user = user
      new_event.message = @delegate.instances['commands'].cc + command
      @delegate.event(self, new_event)
      nil
    else
      e.user = user
    end
  end
  
  def location(e, loct=nil)
    if loct then
      e.user.location = loct
      "location set to #{e.user.location}"
    else
      e.user.location
    end
  end
  
  def email(e, em=nil)
    if em then
      e.user.email = em
      "email set to #{e.user.email}"
    else
      e.user.email
    end
  end
  
  def user_defaults_command(e)
    user_defaults.map{ |k,v| "#{k}: #{v}" }.join("\n")
  end
  
  def set_default(e, key, value)
    value = case value
      when 'true' then true
      when 'false' then false
      when 'yes' then true
      when 'no' then false
      else value
    end
    
    user_defaults[key] = value
    "#{key} added to defaults"
  end
  
  def del_default(e, key)
    user_defaults.delete(key)
    "#{key} removed from defaults"
  end
  
  def network(e, n, value=nil)
    if value then
      e.user.add_network(n, value)
      "Username for #{User.networks[n][0]} set to #{value}" if User.networks.has_key?(n)
    else
      if e.user.network?(n) then
        "#{n}: #{e.user.network(n)} (#{e.user.network!(n)})"
      else
        "No username set for #{n}"
      end
    end
  end
  
  def networks(e)
    User.networks.keys.join(', ')
  end
  
  def profile(e, username=nil)
    username = e.user.username unless username
    
    if (user = user!(username)) then
      user.networks.reject{ |n| not User.networks.has_key?(n) }.map{ |n| "#{User.networks[n][0]}: #{user.network(n)}" }.join(', ')
    else
      "No such user"
    end
  end
  
  def message(e, username, message)
    user = user!(username)
    
    if user then
      if e.user.admin? then
        user.send(message)
      else
        user.send("#{e.user.username}: message")
      end
      
      "message sent"
    else
      "no such user"
    end
  end
  
  def broadcast(e, message)
    @users.each do |user|
      user.send(message)
    end
    
    "Message broadcasted to all #{@users.count} users"
  end
end

Plugin.define do 
  name 'users'
  description 'user accounts/permissions system'
  object Users
end
