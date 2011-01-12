class UtilsPlugin <Plugin
  name :utils

  def commands
    {
      'count' => [lambda { |e, data| "#{data.split_seperators.size}" }, {
        :help => 'Count the amount of items in a list' } ],
      'grep' => [:grep, 2, { :help => 'print lines matching a pattern' } ],
      'not' => [:not_command, 2, { :help => 'Opposite to grep' } ],
      'tail' => [:tail, { :help => 'List the last three items in a list' }],
      'echo' => [:echo, { :example => 'Hello, {username}' }],
      'reverse' => lambda { |e, data| data.reverse },
      'first' => lambda { |e, data| data.split_seperators.first },
      'last' => lambda { |e, data| data.split_seperators.last },
      'sub' => [:sub, {
        :help => 'Replace all occurances of a pattern',
        :usage => 'pattern replacement data',
        :example => 'l * Hello World!' }],
      'tr' => [:tr, {
        :help => 'Returns a copy of str with the characters in from_str replaced by the corresponding characters in to_str',
        :usage => 'from_str to_str data',
        :example => 'aeiou * hello' }],
      'downcase' => lambda { |e, data| data.downcase },
      'upcase' => lambda { |e, data| data.upcase },
      'swapcase' => lambda { |e, data| data.swapcase },
      'capitalize' => lambda { |e, data| data.capitalize },
    }
  end

  def grep(e, search, data)
    data.split_seperators.reject{ |d| not d.include?(search) }.join(', ')
  end
  
  def not_command(e, search, data)
    data.split_seperators.reject{ |d| d.include?(search) }.join(', ')
  end
  
  def tail(e, data)
    data.split_seperators.reverse[0..2].join(', ')
  end
  
  def echo(e, data)
    "#{data}"
  end
  
  def sub(e, pattern, replacement, data)
    data.gsub(pattern, replacement)
  end
  
  def tr(e, from_str, to_str, data)
    data.tr(from_str, to_str)
  end
end
