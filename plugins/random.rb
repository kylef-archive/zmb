class Random <Plugin
  name :random
  description 'Commands for coinflips, dice, yesno, random'

  def initialize(sender, settings); end
  
  def commands
    {
      'random' => [:random, {
        :help => 'Select a item randomly from a list',
        :usage => 'item 1, item 2, item 3',
        :example => 'egg, tomatoe, sausage' }],
      'yesno' => [:yesno, 0, { :help => 'yes or no?' }],
      'headstails' => [:coinflip, 0, { :help => 'Flip a coin' }],
      'coinflip' => [:coinflip, 0, { :help => 'Flip a coin' }],
      'dice' => [lambda { |e| "#{rand(6) + 1}" }, 0, { :help => 'Roll a dice' }],
    }
  end
  
  def random(e, args)
    items = args.split_seperators
    "#{items[rand(items.size)]}"
  end
  
  def yesno(e)
    random(e, ['yes', 'no'])
  end
  
  def coinflip(e)
    random(e, ['heads', 'tails'])
  end
end
