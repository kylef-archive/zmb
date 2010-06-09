class String
  def self.random(len=8)
    characters = ('a'..'z').to_a + ('1'..'9').to_a
    (1..len).map{ characters[rand(characters.size)] }.join
  end
  
  def split_seperators
    if include?("\n") then
      split("\n").map{ |arg| arg.strip }
    elsif include?(',') then
      split(',').map{ |arg| arg.strip }
    elsif include?(' ') then
      split(' ')
    else
      [self]
    end
  end
  
  def truncate_words(num)
    return [self] if size <= num
    
    lines = Array.new
    line = Array.new
    len = 0
    
    split(' ').each do |word|
      len += 1 unless len == 0
      len += word.size
      
      if not len <= num then
        lines << line.join(' ')
        line = Array.new
        len = word.size
      end
      
      line << word
    end
    
    lines << line.join(' ') if lines.size != 0
    
    lines
  end
  
  def plural(amount=2)
    if amount == 1 then
      self
    else
      self + 's'
    end
  end
  
  def http(type, q=nil)
    u = URI.parse(self)
    
    http = Net::HTTP.new(u.host, u.port)
    q = q.to_query_string if q.class == Hash
    q = u.query unless q
    
    http.start do |h|
      case type
        when 'get' then h.get(u.path + '?' + q)
        when 'post' then h.post(u.path, q)
        when 'head' then h.head(u.path + '?' + q)
      end
    end
  end
  
  def get(q={})
    http('get', q)
  end
  
  def post(q={})
    http('post', q)
  end
end

class Array
  def split_seperators
    self
  end
  
  def word_count(seperator='')
    join(seperator).size
  end
  
  def list_join
    (size > 2 ? [slice(0..-2).join(', '), last] : self).join(' and ')
  end
  
  def list_count
    items = {}
    
    each do |i|
      items[i] = 0 unless items.has_key?(i)
      items[i] += 1
    end
    
    items.map{ |i, c| c == 1 ? i : "#{i} (#{c})" }.join(', ')
  end
  
  def sum
    inject {|result, element| result + element}
  end
  
  def avg
    sum / count
  end
end

class Hash
  def to_query_string
    map { |k, v| 
      if v.instance_of?(Hash)
        v.map { |sk, sv|
          "#{k}[#{sk}]=#{sv}"
        }.join('&')
      else
        "#{k}=#{v}"
      end
    }.join('&')
  end
end

class Time
  def since
    Time.now - self
  end
  
  def since_words
    s = since
    m = Array.new
    s = s * -1 if future = (s < 0) # Is the time in the future?
    
    [
      ['year',   60 * 60 * 24 * 365],
      ['month',  60 * 60 * 24 * 30],
      ['week',   60 * 60 * 24 * 7],
      ['day',    60 * 60 * 24],
      ['hour',   60 * 60],
      ['minute', 60],
      ['second', 1],
    ].each do |word, t|
      amount = (s/t).floor
      s -= amount * t
      m << "#{amount} #{word.plural(amount)}" unless amount == 0
    end
    
    m << 'now' if m.size == 0
    
    m.list_join + (future ? ' left' : '')
  end
end
