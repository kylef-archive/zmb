class String
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
      ['week', 604800],
      ['day', 86400],
      ['hour', 3600],
      ['minute', 60],
      ['second', 1],
    ].each do |word, t|
      amount = (s/t).floor
      s -= amount * t
      m << "#{amount} #{word.plural(amount)}" unless amount == 0
    end
    
    m.list_join + (future ? ' left' : '')
  end
end