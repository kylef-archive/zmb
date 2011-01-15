require 'digest'
require 'base64'

require 'commands'

MORSE = {
  '-----' => '0',
  '.----' => '1',
  '..---' => '2',
  '...--' => '3',
  '....-' => '4',
  '.....' => '5',
  '-....' => '6',
  '--...' => '7',
  '---..' => '8',
  '----.' => '9',
  '.-' => 'a',
  '-...' => 'b',
  '-.-.' => 'c',
  '-..' => 'd',
  '.' => 'e',
  '..-.' => 'f',
  '--.' => 'g',
  '....' => 'h',
  '..' => 'i',
  '.---' => 'j',
  '-.-' => 'k',
  '.-..' => 'l',
  '--' => 'm',
  '-.' => 'n',
  '---' => 'o',
  '.--.' => 'p',
  '--.-' => 'q',
  '.-.' => 'r',
  '...' => 's',
  '-' => 't',
  '..-' => 'u',
  '...-' => 'v',
  '.--' => 'w',
  '-..-' => 'x',
  '-.--' => 'y',
  '--..' => 'z',
  '-..-.' => '/',
  '.-.-.' => '+',
  '-...-' => '=',
  '.-.-.-' => '.',
  '--..--' => ',',
  '..--..' => '?',
  '-.--.' => '(',
  '-.--.-' => ')',
  '-....-' => '-',
  '.-..-.' => '"',
  '..--.-' => '_',
  '.----.' => "'",
  '---...' => ':',
  '-.-.-.' => ';',
  '...-..-' => '$',
  '/' => ' ',
}

class Security <Plugin
  extend Commands

  name :security
  description 'Hashes, morse code and base64.'

  command :morse do
    help 'Encode text into morse code'
    example 'Hello World'

    call do |m, data|
      data.downcase.split('').map{ |c| MORSE.index(c) }.join(' ')
    end
  end

  command :demorse do
    help 'Convert morse code into plain text'
    example '.... . .-.. .-.. --- / .-- --- .-. .-.. -..'

    call do |m, data|
      data.downcase.split('').map{ |c| MORSE.index(c) }.join(' ')
    end
  end

  command!(:rot13) { |m, data| data.tr('A-Ma-mN-Zn-z', 'N-Zn-zA-Ma-m') }
  command!(:sha1) { |m, data| Digest::SHA1.hexdigest(data) }
  command!(:sha256) { |m, data| Digest::SHA256.hexdigest(data) }
  command!(:md5) { |m, data| Digest::MD5.hexdigest(data) }
  command!(:base64) { |m, data| Base64.encode64(data) }
  command!(:decode64) { |m, data| Base64.decode64(data) }
end
