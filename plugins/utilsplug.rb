require 'commands'

class UtilsPlugin <Plugin
  extend Commands

  name :utils

  command :count do
    help 'Count the amount of items in a list'
    call { |m, list| "#{list.split_seperators.size}" }
  end

  command :grep do
    help 'Print lines matchig a pattern'
    regex /^(\S+) (.+)$/

    call do |m, search, data|
      data.split_seperators.reject{ |d| not d.include?(search) }.join(', ')
    end
  end

  command :not do
    help 'The opposite to grep'
    regex /^(\S+) (.+)$/

    call do |m, search, data|
      data.split_seperators.reject{ |d| d.include?(search) }.join(', ')
    end
  end

  command :tail do
    help 'List the last three items in a list'
    call do |m, data|
      data.split_seperators.reverse[0..2].join(', ')
    end
  end

  command!(:echo) { |m, data| "#{data}" }
  command!(:reverse) { |m, data| data.reverse }
  command!(:first) { |m, data| data.split_seperators.first }
  command!(:last) { |m, data| data.split_seperators.last }
  command!(:downcase) { |m, data| data.downcase }
  command!(:upcase) { |m, data| data.upcase }
  command!(:swapcase) { |m, data| data.swapcase }
  command!(:capitalize) { |m, data| data.capitalize }

  command :sub do
    help 'Replace all occurances of a pattern'
    usage 'pattern replacement data' => 'l * Hello World!'
    regex /^(\S+) (\S+) (.+)$/

    call do |m, pattern, replacement, data|
      data.gsub(pattern, replacement)
    end
  end
end
