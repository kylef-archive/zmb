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
  
  def saw(message=nil)
    @settings['seen'] = Time.now
    
    if message then
      buffer.each do |m|
        message.user.message(m)
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

class Users <Plugin
  name :users
  description 'user accounts/permissions system'

  attr_accessor :users, :user_defaults
  
  def initialize(sender, s={})
    super
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

  def irc_message(connection, message)
    message.opts[:user] = user(message.user.userhost, true)
    message.opts[:user].saw(message)
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
      'whoami' => [lambda { |m| "#{m.ops[:user]}" }, 0, { :help => 'Who are you logged in as?' }],
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
  
  def activate(message, username)
    if user = user!(username) then
      user.activate
      "#{username} active"
    else
      "#{username} does not exist"
    end
  end
  
  def deactivate(message, username)
    if user = user!(username) then
      user.deactivate
      "#{username} deactivated"
    else
      "#{username} does not exist"
    end
  end
  
  def meet(message, username=nil)
    username = message.user.nick if not message.opts[:user].admin?
    
    if username == 'nobody' then
      "nobody is a excluded name"
    elsif not user!(username) then
      @users << user = User.new(@user_defaults.merge({'username' => username}))
      user.userhosts << message.user.userhost if not message.opts[:user].admin?
      "Hello #{user}"
    else
      "You already have an account #{message.opts[:user]}"
    end
  end
  
  def forget(message, username=nil)
    if message.opts[:user].admin? and username then
      "user #{@users.delete(user(username))} deleted"
    else
      "user #{@users.delete(message.opts[:user].user)} deleted"
    end
  end
  
  def permit(message, username, permission)
    if user = user!(username) then
      user.permit(permission)
      "permission added"
    else
      "#{username} does not exist"
    end
  end
  
  def deny(message, username, permission)
    if user = user!(username) then
      user.deny(permission)
      'permission removed'
    else
      "#{username} does not exist"
    end
  end
  
  def perms(message)
    if message.opts[:user].permissions.empty?
      "#{message.opts[:user]} has no permissions"
    else
      message.opts[:user].permissions.join(', ')
    end
  end
  
  def group(message, group)
    @users.reject{ |user| not user.permissions.include?(group) }.join(', ')
  end
  
  def merge(message, username, other_username)
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
  
  def password(message, password)
    message.opts[:user].password = password
    "#{message.opts[:user]} password has been set to #{password}"
  end
  
  def login(message, username, password)
    user = user!(username)
    
    if user and user.password?(password) then
      user.userhosts << message.opts[:user].userhost
      "#{message.opts[:user].userhost} added to your account #{user}"
    else
      'user and/or password is incorrect'
    end
  end
  
  def logout(message)
    message.opts[:user].userhosts.delete(message.user.userhost)
    "userhost #{message.user.userhost} removed from your account."
  end
  
  def userhosts(message)
    message.opts[:user].userhosts.empty? ? "#{message.opts[:user]} has no userhosts" : message.opts[:user].userhosts.join(', ')
  end
  
  def adduserhost(message, userhost)
    message.opts[:user].userhosts << userhost
    "#{userhost} added to #{message.opts[:user]}"
  end
  
  def rmuserhost(message, userhost)
    if message.opts[:user].userhosts.delete(userhost) then
      "#{userhost} deleted from #{message.opts[:user]}"
    else
      "#{message.opts[:user]} doesn't have #{userhost}"
    end
  end
  
  def names(message, search=nil)
    users = @users.map{ |user| user.username }
    users = users.grep(/#{search}/i) if search
    
    if users.empty? then
      "no users found"
    else
      users.join(', ')
    end
  end
  
  def seen(message, username)
    if username == message.opts[:user].username then
      "Are you looking for yourself?"
    elsif user = user!(username) and user.seen then
      "#{username} last seen #{user.seen.since_words}"
    else
      "#{username} has never been seen"
    end
  end
  
  def sudo(message, username, command=nil)
    user = user(username)
    
    if command then
      new_message = message.clone
      new_message.opts[:user] = user
      new_message.replace(zmb.plugin(:commands).cc + command)
      zmb.plugin(:commands).irc_message(message.user.connection, new_message)
      nil
    else
      message.opts[:user] = user
    end
  end
  
  def location(message, loct=nil)
    if loct then
      message.opts[:user].location = loct
      "location set to #{loct}"
    else
      message.opts[:user].location
    end
  end
  
  def email(message, var=nil)
    if var then
      message.opts[:user].email = var
      "email set to #{var}"
    else
      message.opts[:user].email
    end
  end
  
  def user_defaults_command(message)
    user_defaults.map{ |k,v| "#{k}: #{v}" }.join("\n")
  end
  
  def set_default(message, key, value)
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
  
  def del_default(message, key)
    user_defaults.delete(key)
    "#{key} removed from defaults"
  end
  
  def network(message, n, value=nil)
    if value then
      message.opts[:user].add_network(n, value)
      "Username for #{User.networks[n][0]} set to #{value}" if User.networks.has_key?(n)
    else
      if message.opts[:user].network?(n) then
        "#{n}: #{message.opts[:user].network(n)} (#{message.opts[:user].network!(n)})"
      else
        "No username set for #{n}"
      end
    end
  end
  
  def networks(message)
    User.networks.keys.join(', ')
  end
  
  def profile(message, username=nil)
    username = message.opts[:user].username unless username
    
    if (user = user!(username)) then
      user.networks.reject{ |n| not User.networks.has_key?(n) }.map{ |n| "#{User.networks[n][0]}: #{user.network(n)}" }.join(', ')
    else
      "No such user"
    end
  end
  
  def message(message, username, m)
    user = user!(username)
    
    if user then
      if message.opts[:user].admin? then
        user.send(m)
      else
        user.send("#{message.opts[:user].username}: #{m}")
      end
      
      "message sent"
    else
      "no such user"
    end
  end
  
  def broadcast(message, m)
    @users.each do |user|
      user.send(m)
    end
    
    "Message broadcasted to all #{@users.count} users"
  end
end
