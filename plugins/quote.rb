class Quote <Plugin
  name :quote
  description "quote database"

  attr_accessor :quotes, :autoindex

  def initialize(sender, s={})
    super
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

  command :quote do
    help 'Show a random quote or a quote matching the id supplied'
    usage '[quote_id]'
    regex /^(\d+)?$/

    call do |m, quote_id|
      if quote_id
        return "Quote: #{id} not found" unless @quotes.has_key?(quote_id)
      else
        quote_id = "#{rand(autoindex - 1) + 1}"
        while not @quotes.has_key?(quote_id)
          quote_id = "#{rand(autoindex - 1) + 1}"
        end
      end

      "\"#{@quotes[quote_id]['quote']}\" by #{@quotes[quote_id]['username']} at #{@quotes[quote_id]['time']}"
    end
  end

  command :quote_add do
    help 'Add a quote'
    usage 'quote' => '<kylef> Hello world!'
    permission :authenticated
    regex /^(.+)$/

    call do |m, quote|
      add(quote, m.opts[:user].username)
    end
  end
  
  command :quote_rm do
    help 'Remove a quote'
    usage 'quote_id' => '5'
    regex /^(\d+)?$/
    permission :admin

    call do |m, quote_id|
      if @quotes.has_key?(quote_id)
        @quotes.delete id
        "Quote #{quote_id} has been deleted"
      else
        "No quotes found with the id=#{quote_id}"
      end
    end
  end

  command :quote_last do
    help 'Show the last quote added'
    return "no quotes" if count < 1
    quote_command(e, @quotes.keys.sort.reverse[0])
  end

  command :quote_search do
    help 'Search to find a quote'
    regex /^(.+)$/

    call do |m, search|
      result = @quotes.map{ |id, quote| "#{id}: #{quote['quote']}" if quote['quote'].include?(search) }.reject{ |q| not q }

      if result.count then
        result.join("\n")
      else
        "no quotes found"
      end
    end
  end
end
end
