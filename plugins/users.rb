require 'commands'

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
    if permission == :authenticated
      true
    else
      admin? or permissions.include?(permission)
    end
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

  def username
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
  extend Commands

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
    message.opts[:user].saw(message) if message.opts[:user].respond_to?(:saw)
  end

  command :activate do
    help 'Activate a users account'
    usage 'username' => 'kylef'
    permission :admin
    regex /^(\S+)$/

    call do |m, username|
      user = user!(username)
      
      if user
        user.activate
        "#{username} activated"
      else
        "#{username} does not exist."
      end
    end
  end

  command :deactivate do
    help 'Deactivate a users account'
    usage 'username' => 'kylef'
    permission :admin
    regex /^(\S+)$/

    call do |m, username|
      user = user!(username)
      
      if user
        user.deactivate
        "#{username} deactivated"
      else
        "#{username} does not exist."
      end
    end
  end

  command :meet do
    help 'Meet a user'

    call do |m, username|
      username = m.user.nick unless m.opts[:user].admin?

      if m.opts[:user].authenticated?
        "#{m.ops[:user].username}: You already have a useraccount"
      elsif username == 'nobody'
        'The username `nobody` is not allowed. Please try a different username.'
      elsif user!(username)
        "An account with the #{username} is already registered, please try a different username"
      else
        u = User.new(@user_defaults.merge({'username' => username}))
        u.userhosts << message.user.userhost unless message.opts[:user].admin?
        @users << u

        "Hello, #{u.username}"
      end
    end
  end

  command!(:whoami){ |m| "#{m.opts[:user]}" }

  command :forget do
    help 'Forget a user'
    permission :authenticated

    call do |m, username|
      if m.opts[:user].admin? and username
        u = username!(username)
        if u
          "User #{@users.delete(u)} deleted."
        else
          "#{username}: User not found."
        end
      else
        "User #{@users.delete(message.opts[:user])} deleted."
      end
    end
  end

  command :permit do
    help 'Grant a permission to a user'
    usage 'user permission' => 'kylef admin'
    regex /^(\S+)\s+(\S+)$/
    permission :admin

    call do |m, user, permission|
      u = user!(username)

      if u
        user.permit(permission)
        "#{username} has been granted #{permission}"
      else
        "#{username} does not exist."
      end
    end
  end

  command :deny do
    help 'Revoke a permission from a user'
    usage 'user permission' => 'kylef admin'
    regex /^(\S+)\s+(\S+)$/
    permission :admin

    call do |m, user, permission|
      u = user!(username)

      if u
        user.deny(permission)
        "#{permission} has been removed from #{username}."
      else
        "#{username} does not exist."
      end
    end
  end
  
  command :perms do
    help 'List all the permissions you have.'
    permission :authenticated

    call do |m|
      if m.opts[:user].permissions.empty?
        "You do not have any permissions"
      else
        m.opts[:user].permissions.join(', ')
      end
    end
  end

  command :group do
    help 'List all users who have the matching permission'
    usage 'perm' => 'admin'
    permission :admin

    call do |m, perm|
      @users.select{ |u| u.permission?(perm) }.join(', ')
    end
  end

  command :merge do
    help 'Merge two users together, give user a the permissions and useragents of b and then delete b'
    usage 'user_a user_b'
    permission :admin
    regex /^(\S+)\s+(\S+)$/

    call do |m, user_a, user_b|
      a = user!(user_a)
      b = user!(user_b)

      if a and b
        a.concat user_b
        @users.delete(b)
        "#{b} has been merged into #{a}"
      else
        'User(s) do not exist'
      end
    end
  end

  command :password do
    help 'Set the password for your account.'
    usage 'password' => 'test'
    permission :authenticated
    regex /^(\S+)$/

    call do |m, password|
      message.opts[:user].password = password
      "#{message.opts[:user]} password has been set to #{password}"
    end
  end

  command :login do
    help 'Login to your account, adding your current userhost to your account.'
    usage 'username password' => 'kylef test'
    regex /^(\S+)\s+(\S+)$/

    call do |m, username, password|
      user = user!(username)

      if user and user.password?(password)
        user.userhosts << m.user.userhost
        "#{m.user.userhost} has been added to your account #{username}"
      else
        "username and/or password is incorrect"
      end
    end
  end

  command :logout do
    help 'Logout from your account, this will remove your current userhost from your account.'
    permission :authenticated
    
    call do |m|
      message.opts[:user].userhosts.delete(message.user.userhost)
      "The userhost #{message.user.userhost} has been removed from your account"
    end
  end

  command :userhosts do
    help 'List all the userhosts associated with your account.'
    permission :authenticated

    call do |m|
      if m.opts[:user].userhosts.empty?
        "#{m.opts[:user]} has no userhosts"
      else
        m.opts[:user].userhosts.join(', ')
      end
    end
  end

  command :adduserhost do
    help 'Add a userhost to your account.'
    usage 'userhost' => 'kylef@localhost'
    permission :authenticated
    regex /^(\S+)$/

    call do |m, userhost|
      m.opts[:user].userhosts << userhost
      "#{userhost} added to #{m.opts[:user]}"
    end
  end

  command :rmuserhost do
    help 'Remove a userhost from your account.'
    usage 'userhost' => 'kylef@localhost'
    permission :authenticated
    regex /^(\S+)$/

    call do |m, userhost|
      if m.opts[:user].userhosts.delete(userhost)
        "#{userhost} remove from #{m.opts[:user]}"
      else
        "#{userhost} not found for #{m.opts[:user]}"
      end
    end
  end

  command :names do
    help 'List all registered users'
    usage 'search' => 'ky'

    call do |m, search|
      users = @users.map{ |u| u.username }
      users = users.grep(/#{search}/i) if search

      if users.empty?
        "No users found"
      else
        users.join(', ')
      end
    end
  end

  command :seen do
    help 'When was a user last seen?'
    usage 'user' => 'kylef'
    regex /^(\S+)$/

    call do |m, username|
      if username == m.opts[:user].username
        "Are you looking for yourself?"
      elsif (user = user!(username)) and user.seen
        "#{username} was last seen #{user.seen.since_words}"
      else
        "#{username} has never been seen."
      end
    end
  end

  command :sudo do
    help 'Execute a command as another user.'
    usage 'user [command]' => 'kylef whoami'
    permission :admin
    regex /^(\S+)(\s+(\S+)?)$/

    call do |m, username, whitespace, command|
      user = user!(username)

      if not user
        "#{username}: User not found"
      elsif command
        nmessage = message.clone
        nmessage.opts[:user] = user
        nmessage.replace(zmb.plugin(:commands).cc + command)
        zmb.plugin(:commands).irc_message(message.user.connection, nmessage)
      else
        m.opts[:user] = user
      end
    end
  end

  command :location do
    help 'Set your location'
    permission :authenticated

    call do |m, location|
      if location
        m.opts[:user].location = location
        "Your location has been set to #{location}."
      else
        m.opts[:user].location
      end
    end
  end

  command :email do
    help 'Set your email'
    permission :authenticated

    call do |m, email|
      if email
        m.opts[:user].email = email
        "Your email address has been set to #{email}"
      else
        m.opts[:user].email
      end
    end
  end

  command :"user-defaults" do
    help 'List all the user defaults'
    permission :admin

    call do |m|
      user_defaults.map{ |k,v| "#{k}: #{v}" }.join("\n")
    end
  end

  command :"user-default" do
    help 'Set a user default'
    usage 'key value' => 'activate no'
    permission :admin
    regex /^(\S+)\s+(\S+)$/

    call do |m, key, value|
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
  end

  command :"rm-user-default" do
    help 'Remove a user default'
    usage 'key' => 'active'
    permission :admin
    regex /^(\S+)$/

    call do |m, key|
      user_defaults.delete(key)
      "#{key} removed from defaults"
    end
  end

  command :network do
    help 'Set a username for a network, see `networks` for a list of networks'
    usage 'network [username]' => 'lastfm kylef'
    permission :authenticated
    regex /^(\S+)(\s+(\S+)?)$/

    call do |m, network, value|
      if value
        m.opts[:user].add_network(network, value)
        "#{network} has been set to #{value}"
      else
        if m.opts[:user].network?(network)
          "#{network}: #{m.opts[:user].network(network)} (#{m.opts[:user].network!(network)})"
        else
          "This network has not been set"
        end
      end
    end
  end

  command :networks do
    help 'List all availible networks'

    call { |m| User.networks.keys.join(', ') }
  end

  def profile(message, username=nil)
    username = message.opts[:user].username unless username
    
    if (user = user!(username)) then
      user.networks.reject{ |n| not User.networks.has_key?(n) }.map{ |n| "#{User.networks[n][0]}: #{user.network(n)}" }.join(', ')
    else
      "No such user"
    end
  end

  command :profile do
    call do |m, username|
      username = m.opts[:user].username unless username

      if (user = user!(username))
        user.networks.select{ |n| User.networks.has_key?(n) }.map{ |n| "#{User.networks[n][0]}: #{user.network(n)}" }.join(', ')
      else
        "#{username}: User not found"
      end
    end
  end

  command :message do
    help 'Send a message to another user'
    permission :authenticated
    regex /^(\S+)\s+(\S+)$/

    call do |m, username, message|
      user = user!(username)

      if user
        user.send("#{m.opts[:user]}: #{message}")
        "Message sent to #{username}"
      else
        "#{username}: User not found"
      end
    end
  end

  command :broadcast do
    help 'Broadcast a message to every user'
    usage 'message' => 'Hello everyone!'
    permission :admin

    call do |m, content|
      @users.each do |user|
        user.send(content)
      end

      "Message broadcasted to all #{@users.count} users"
    end
  end
end
