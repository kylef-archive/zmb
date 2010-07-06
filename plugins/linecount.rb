class LineCount
  attr_accessor :users
  
  def initialize(sender, s)
    @users = s['users'] if s.has_key?('users')
    @users = Hash.new if not @users
  end
  
  def settings
    { 'users' => @users }
  end
  
  def commands
    {
      'linecount' => :linecount,
      'lines' => [:lines, 0],
    }
  end
  
  def event(sender, e)
    if e.message? and not e.private? and e.respond_to?('user') and e.user.authenticated? then
      if @users.has_key?(e.user.username) then
        @users[e.user.username] += 1
      else
        @users[e.user.username] = 1
      end
    end
  end
  
  def linecount(e, user=nil)
    user = e.user.username if not user and e.respond_to?('user')
    
    if @users.has_key?(user) then
      "#{user} has said #{@users[user]} lines"
    else
      "#{user} has not said anything"
    end
  end
  
  def lines(e)
    @users.invert.sort.reverse[0..5].map{ |l,u| "#{u} (#{l})"}.join(', ')
  end
end

Plugin.define do
  name 'linecount'
  description 'Count the amount of lines users type'
  object LineCount
end
