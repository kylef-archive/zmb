class Poll
  def initialize(sender, s={})
    @polls = Hash.new
    @polls = s['polls'] if s.has_key?('polls')
  end
  
  def settings
    { 'polls' => @polls }
  end
  
  def add(slug, poll)
    @polls[slug] = {'poll' => poll, 'options' => [], 'votes' => {}}
  end
  
  def add_opt(slug, option)
    @polls[slug]['options'] << option
  end
  
  def add_vote(username, slug, option)
    @polls[slug]['votes'][username] = option
  end
  
  def poll_opt?(slug, opt)
    @polls[slug]['options'].values_at(opt)[0] != nil
  end
  
  def poll_count(slug, opt)
    @polls[slug]['votes'].reject{ |k,v| v != opt }.size
  end
  
  def commands
    {
      'poll-add' => [:add_command, 2, { :permission => 'admin' }],
      'poll-opt' => [:opt_command, 2, { :permission => 'admin' }],
      'poll-del' => [:del_command, 1, { :permission => 'admin' }],
      'vote' => [:vote_command, 2],
      'polls' => [:polls_command, 0],
      'poll' => :poll_command,
    }
  end
  
  def add_command(e, slug, poll)
    add(slug, poll)
    "#{poll} added as #{slug}"
  end
  
  def opt_command(e, slug, option)
    add_opt(slug, option)
    "#{option} added to #{slug}"
  end
  
  def del_command(e, slug)
    @polls.delete(slug)
    "#{slug} deleted"
  end
  
  def vote_command(e, slug, option)
    return "permission denied" if not e.user.authenticated?
    
    begin
      opt = Integer(option)-1
    rescue ArgumentError
      return "Option must be a number"
    end
    
    if @polls.has_key?(slug) then
      if poll_opt?(slug, opt) then
        add_vote(e.user.username, slug, opt)
        "Vote added"
      else
        "Option #{opt+1} doesn't exist for #{slug}"
      end
    else
      "#{slug}: poll doesn't exist"
    end
  end
  
  def polls_command(e)
    if @polls.size > 0 then
      @polls.map{ |k,v| "#{k}: #{v['poll']}"}.join("\n")
    else
      "No polls found"
    end
  end
  
  def poll_command(e, slug)
    if @polls.has_key?(slug) then
      poll = @polls[slug]
      x = 0
      "#{poll['poll']}\n" + poll['options'].map{ |o| "#{x += 1}: #{o} (#{poll_count(slug, x-1)})" }.join("\n")
    else
      "#{slug}: poll doesn't exist"
    end
  end
end

Plugin.define do
  name 'poll'
  description 'voting plugin'
  object Poll
end
