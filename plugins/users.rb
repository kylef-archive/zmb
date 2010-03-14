class Event
  attr_accessor :user, :users
end

class User
  require 'digest/sha1'
  
  attr_accessor :username, :password, :userhosts, :permissions, :seen, :users
  
  def to_json(*a)
    {'username' => @username, 'password' => @password, 'userhosts' => @userhosts, 'permissions' => @permissions, 'seen' => @seen}.to_json(*a)
  end
  
  def self.create_settings(data)
    require 'time'
    user = new(data['username'])
    user.raw_password = data['password']
    user.userhosts = data['userhosts'] if data.has_key?('userhosts')
    user.permissions = data['permissions'] if data.has_key?('permissions')
    user.seen = Time.parse(data['seen']) if data.has_key?('seen') and data['seen']
    user
  end
  
  def initialize(username=nil, password=nil, userhost=nil)
    @username = username
    @password = Digest::SHA1.hexdigest(password) if password
    @userhosts = Array.new
    @userhosts << userhost if userhost
    @permissions = Array.new
  end
  
  def concat(other_user)
    @permissions += other_user.permissions
    @userhosts += other_user.userhosts
  end
  
  def raw_password=(new_password)
    @password = new_password
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
  
  def initialize(sender, s={})
    @delegate = sender
    @users = s['users'].map{ |user| User.create_settings(user) } if s.has_key?('users')
    @users = Array.new if not @users
  end
  
  def settings
    { 'users' => @users }
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
    e.users = self
  end
  
  def create_user(username, password=nil, userhost=nil)
    user = User.new(username, password, userhost)
    @users << user
    user
  end
  
  def commands
    {
      'meet' => [:meet, 1, { :help => 'Meet a user' }],
      'forget' => [:forget, 0, {
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
      'whoami' => [:whoami, 0, { :help => 'Who are you logged in as?' }],
      'userhosts' => [:userhosts, 0, {
        :help => 'List all the userhosts associated with your account.' }],
      'adduserhost' => [:adduserhost, 1, { :help => 'Add a userhost to your account.' }],
      'rmuserhost' => [:rmuserhost, 1, { :help => 'Remove a userhost to your account.' }],
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
    }
  end
  
  def meet(e, username=nil)
    if e.user.admin? and username then
      return "#{username} already exists" if user!(username)
      user = create_user(username)
      "Hello #{username}"
    elsif not e.user.authenticated? then
      return "#{e.sender} already exists" if user!(e.sender)
      if e.respond_to?('userhost') and e.respond_to?('user') then
        user = create_user(e.name, nil, e.userhost)
      end
      "Hello #{user.username}"
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
  
  def perms(e)
    e.user.permissions.empty? ? "#{e.user.username} has no permissions" : e.user.permissions.join(', ')
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
    
    if user and user.password?(password) then
      user.userhosts << e.userhost
      "#{e.userhost} added to your account #{user.username}"
    else
      'user and/or password is incorrect'
    end
  end
  
  def logout(e)
    e.user.userhosts.delete(e.userhost)
    "userhost #{e.userhost} removed from your account."
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
  
  def rmuserhost(e, userhost)
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
