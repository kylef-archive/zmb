class Quote <Plugin
  name :quote
  description "quote database"

  attr_accessor :quotes, :autoindex
  
  def initialize(sender, s={})
    @quotes = Hash.new
    @quotes = s['quotes'] if s.has_key?('quotes')
    @autoindex = 1
    @autoindex = s['autoindex'] if s.has_key?('autoindex')
  end
  
  def settings
    { 'quotes' => @quotes, 'autoindex' => @autoindex }
  end
  
  def add(quote, username=nil)
    @quotes["#{@autoindex}"] = {
      'quote' => quote,
      'time' => Time.now,
      'username' => username,
    }
    
    @autoindex += 1
    @autoindex - 1
  end
  
  def count
    @quotes.keys.count
  end
  
  def commands
    {
      'quote' => [:quote_command, {
        :help => 'Show a random quote or the quote with matching id',
        :usage => 'id' }],
      'quote-add' => [:add_command, {
        :help => 'Add a quote',
        :example => 'zynox: Hello!' }],
      'quote-del' => [:del_command, { 
        :help => 'Delete a quote by id',
        :example => '7'}],
      'quote-count' =>[lambda { |e| "#{count} quotes" }, 0, {
        :help => 'Show amount of quotes' }],
      'quote-last' => [:last_command, 0, { :help => 'Show the last quote' }],
      'quote-search' => [:search_command, {
        :help => 'Search to find a quote',
        :usage => 'search' }],
    }
  end
  
  def quote_command(e, id=nil)
    return "quote \##{id} not found" if id and not @quotes.has_key?(id)
    return "\"#{@quotes[id]['quote']}\" by #{@quotes[id]['username']} at #{@quotes[id]['time']}" if id
    return "no quotes" if count < 1
    
    id = "#{rand(autoindex - 1) + 1}"
    while not @quotes.has_key?(id)
      id = "#{rand(autoindex - 1) + 1}"
    end
    
    "\"#{@quotes[id]['quote']}\" by #{@quotes[id]['username']} at #{@quotes[id]['time']}"
  end
  
  def add_command(e, quote)
    if e.user and e.user.respond_to?('authenticated?') and e.user.authenticated? then
      "quote added \##{add(quote, e.user.username)}"
    else
      'permission denied'
    end
  end
  
  def del_command(e, id)
    if @quotes.has_key?(id) then
      @quotes.delete id
      "quote #{id} deleted"
    else
      "no quote found with id=#{id}"
    end
  end
  
  def last_command(e)
    return "no quotes" if count < 1
    quote_command(e, @quotes.keys.sort.reverse[0])
  end
  
  def search_command(e, search)
    result = @quotes.map{ |id, quote| "#{id}: #{quote['quote']}" if quote['quote'].include?(search) }.reject{ |q| not q }
    
    if result.count then
      result.join("\n")
    else
      "no quotes found"
    end
  end
end
