class Vouch <Plugin
  name :vouch
  description 'Make users require votes from another user to activate their account'

  attr_accessor :settings
  
  def defaults
    { 'votes' => Hash.new, 'archive' => Hash.new, 'limit' => 2 }
  end
  
  def initialize(sender, s)
    @settings = defaults.merge(s)
  end
  
  def votes
    @settings['votes']
  end
  
  def archive
    @settings['archive']
  end
  
  def limit
    @settings['limit']
  end
  
  def commands
    {
      'vouch' => [:vouch, {
        :permission => 'authenticated',
        :help => 'Vouch for a user',
        :usage => 'username',
        :example => 'zynox' }],
      'vouch-limit' => [:limit_command, {
        :permission => 'admin',
        :help => 'Change the vouch limit' }],
      'stats' => [:stats, {
        :help => 'View status of a vouch' }],
    }
  end
  
  def vouch(e, username)
    if user = e.users.user!(username, false) then
      votes[username] = Array.new unless votes.has_key?(username)
      votes[username] << {
        'username' => e.user.username,
        'time' => Time.now,
      }
      
      if votes[username].size >= limit then
        user.activate
        archive[username] = votes[username]
        votes.delete(username)
        "User #{username} now active"
      else
        "You have vouched for #{username}"
      end
    else
      "No such user #{username}, or user already active"
    end
  end
  
  def limit_command(e, l=nil)
    if l == nil then
      "Limit is #{limit}"
    else
      @settings['limit'] = Integer(l)
      "Limit set to #{limit}"
    end
  end
  
  def stats(e, username=nil)
    if username then
      user = e.users.user!(username, false)
      
      if user then
        votes[username] = Array.new unless votes.has_key?(username)
        "#{username} has #{votes[username].size}/#{limit} votes"
      else
        "No such user or user already active"
      end
    else
      users = e.users.users.reject{ |u| u.active? }
      
      if users.size > 0 then
        users.join(', ')
      else
        "no users need vouches"
      end
    end
  end
end
