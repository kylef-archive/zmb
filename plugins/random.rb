require 'commands'

class Random <Plugin
  extend Commands

  name :random
  description 'Commands for coinflips, dice, yesno, random'

  def random(*args)
    args[rand(args.size)]
  end

  command :random do
    help 'Select a item randomly from a list'
    usage 'item 1, item 2, item 3'
    example 'waffles, pancakes, ice creme'

    call do |m, args|
      random(*args.split_seperators)
    end
  end

  command :yesno do
    help 'Yes, or no?'
    
    call do |m|
      random('yes', 'no')
    end
  end

  command :coinflip do
    help 'Flip a coin'

    call do |m|
      random('Heads', 'Tails')
    end
  end

  command :headstails do
    help 'Flip a coin'

    call do |m|
      random('Heads', 'Tails')
    end
  end

  command :dice do
    help 'Roll a dice'

    call do |m|
      "#{rand(6) + 1}"
    end
  end
end
