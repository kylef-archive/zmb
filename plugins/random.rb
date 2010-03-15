class Random
  def initialize(sender, settings); end
  
  def split_seperators(data)
    if data.class == Array then
      data
    elsif data.include?("\n") then
      data.split("\n").map{ |arg| arg.strip }
    elsif data.include?(',') then
      data.split(',').map{ |arg| arg.strip }
    elsif data.include?(' ') then
      data.split(' ')
    else
      data
    end
  end
  
  def commands
    {
      'random' => :random,
      'yesno' => [:yesno, 0],
      'headstails' => [:coinflip, 0],
      'coinflip' => [:coinflip, 0],
      'dice' => [:dice, 0],
    }
  end
  
  def random(e, args)
    items = split_seperators(args)
    "#{items[rand(items.size)]}"
  end
  
  def yesno(e)
    random(e, ['yes', 'no'])
  end
  
  def coinflip(e)
    random(e, ['heads', 'tails'])
  end
  
  def dice(e)
    "#{rand(6) + 1}"
  end
end

Plugin.define do
  name 'random'
  object Random
end
