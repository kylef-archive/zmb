class Event
  attr_accessor :user
end

class User
  require 'digest/sha1'
  
  attr_accessor :username, :password, :userhosts, :permissions, :seen
  
  def to_json(*a)
    {'username' => @username, 'password' => @password, 'userhosts' => @userhosts, 'permissions' => @permissions, 'seen' => @seen}.to_json(*a)
  end
  
  def self.create_settings(data)
    require 'time'
    user = new(data['username'], data['password'])
    user.userhosts = data['userhosts'] if data.has_key?('userhosts')
    user.permissions = data['permissions'] if data.has_key?('permissions')
    user.seen = Time.parse(data['seen']) if data.has_key?('seen') and data['seen']
    user
  end
  
  def initialize(username=nil, password=nil, host=nil)
    @username = username
    @password = Digest::SHA1.hexdigest(password) if password
    @userhosts = Array.new
    @hosts << host if host
    @permissions = Array.new
  end
  
  def concat(other_user)
    @permissions += other_user.permissions
    @userhosts += other_user.userhosts
  end
  
  def password=(new_password)
    @password = Digest::SHA1.hexdigest(new_password)
  end
  
  def password?(check_password)
    @password != nil and @password == Digest::SHA1.hexdigest(check_password)
  end
  
  def authenticated?
    true
  end
  
  def admin?
    @permissions.include?("owner") or @permissions.include?("admin")
  end
  
  def permission?(permission)
    admin? or @permissions.include?(permission)
  end
  
  def permit(permission)
    @permissions << permission
  end
  
  def deny(permission)
    @permissions.delete(permission)
  end
end

class AnonymousUser
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
  attr_accessor :users
  
  def initialize(sender, settings={})
    @delegate = sender
    @users = settings['users'].map{ |user| User.create_settings(user) } if settings.has_key?('users')
    @users = Array.new if not @users
  end
  
  def to_json(*a)
    {'users' => @users, 'plugin' => 'users'}.to_json(*a)
  end
  
  def user!(search)
    @users.find{|user| user.userhosts.include?(search) or user.username == search}
  end
  
  def user(search)
    user!(search) or AnonymousUser.new
  end
  
  def pre_event(sender, e)
    e.user = user(e.userhost) if e.respond_to?('userhost') and not e.user
    e.user.seen = Time.now if e.user.respond_to?('seen')
  end
  
  def commands
    require 'lib/zmb/commands'
    {
      'meet' => Command.new(self, :meet, 1, 'Meet a new user'),
      'forget' => AuthCommand.new(self, :forget, 0, "Forget about a user"),
      'permit' => PermCommand.new('admin', self, :permit, 2),
      'deny' => PermCommand.new('admin', self, :deny, 2),
      'perms' => AuthCommand.new(self, :perms, 1, 'List all permissions a user has.'),
      'merge' => PermCommand.new('admin', self, :merge, 1, 'Merge two users together'),
      'password' => AuthCommand.new(self, :password, 1, 'Set the password for your account'),
      'login' => Command.new(self, :login, 2, 'Add your current host to the username and password provided.'),
      'logout' => AuthCommand.new(self, :logout, 0, 'Remove your current host from your account.'),
      'whoami' => Command.new(self, :whoami, 0, 'Who are you logged in as?'),
      'userhosts' => AuthCommand.new(self, :userhosts, 0, 'List all the hosts associated with your account'),
      'adduserhost' => AuthCommand.new(self, :adduserhost, 1, 'Add a host to your account'),
      'deluserhost' => AuthCommand.new(self, :deluserhost, 1, 'Remove a host to your account'),
      'names' => Command.new(self, :names, 1, 'List all the users'),
      'seen' => Command.new(self, :seen, 1, 'When was a user last seen'),
      'sudo' => PermCommand.new('admin', self, :sudo, 2, 'Execute a command as another user.'),
    }
  end
  
  def meet(e, username=nil)
    if e.user.admin? and username then
      if user!(username) then
        "#{username} already exists"
      else
        user = User.new(username)
        @users << user
        "Hello #{username}"
      end
    elsif not e.user.authenticated? then
      if user!(e.sender) then
        "#{e.sender} already exists"
      else
        if e.respond_to?('userhost') and e.respond_to?('user') then
          user = User.new(e.name)
          user.userhosts << e.userhost
          @users << user
        end
        
        "Hello #{user.username}"
      end
    else
      "You already have an account #{e.user.username}"
    end
  end
  
  def forget(e)
    "user #{@e.users.delete(e.user).username} deleted"
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
  
  def perms(e, username=nil)
    e.user.permissions.empty? ? "#{e.user.username} has no permissions" ? e.user.permissions.join(', ')
  end
  
  def merge(e, username, other_username)
    user = user!(username)
    other_user = user!(other_username)
    
    if user and other_user then
      user.concat other_user 
      @users.delete other_user
      "#{other_user.username} now merged into #{user.username}"
    else
      'User(s) do not exist'
    end
  end
  
  def password(e, password)
    e.user.password = password
    "#{e.user.username} password has been set to #{password}"
  end
  
  def login(e, username, password)
    user = user!(username)
    
    if e.user.authenticated? then
      'already logged in'
    elsif user and user.password?(password) then
      user.hosts << e.userhost
      "#{request.hostname} added to your account #{user.username}"
    else
      'user and/or password is incorrect'
    end
  end
  
  def logout(e)
    e.user.hosts.delete(e.userhost)
    "userhost #{e.hostname} removed from your account."
  end
  
  def whoami(e)
    e.user.authenticated? ? "#{e.user.username}" : 'nobody'
  end
  
  def userhosts(e)
    e.user.userhosts.empty? ?  "#{e.user.username} has no userhosts" : e.user.userhosts.join(', ')
  end
  
  def adduserhost(e, userhost)
    e.user.userhosts << userhost
    "#{userhost} added to #{e.user.username}"
  end
  
  def deluserhost(e, userhost)
    if e.user.userhosts.delete(userhost) then
      "#{userhost} deleted from #{e.user.username}"
    else
      "#{e.user.username} doesn't have #{userhost}"
    end
  end
  
  def names(e, search=nil)
    users = @users.map{|user| user.username}
    users = users.grep(/#{search}/i) if search
    
    if users.empty? then
      "no users found"
    else
      users.join(', ')
    end
  end
  
  def seen(e, username=nil)
    if user = user!(username) and user.seen then
      diff = Time.now - user.seen
      
      if diff < 60 then
        msg = "#{Integer(diff)} seconds ago"
      elsif diff < 3600 then
        msg = "#{Integer(diff/60)} minutes ago"
      elsif diff < 86400 then
        msg = "about #{Integer(diff/3600)} hours ago"
      else
        msg = "#{Integer(diff/86400)} days ago"
      end
      
      "#{username} last seen #{msg}"
    else
      "#{username} has never been seen"
    end
  end
  
  def sudo(e, search, command)
    if user = user!(search) then
      new_event = e.clone
      new_event.user = user
      new_event.message = @delegate.instances['commands'].cc + command
      @delegate.event(self, new_event)
      nil
    else
      "#{search}: Username or userhost not found"
    end
  end
end

Plugin.define do 
  name "users"
  description "users manager"
  object Users
end
