require 'digest'
require 'base64'

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

class Security
  def initialize(sender, s) ;end
  
  def commands
    {
      'morse' => [:morse, 1, {
        :help => 'Encode text into morse code',
        :example => 'Hello World' }],
      'decode-morse' => [:demorse, 1, {
        :help => 'Convert morse code into text',
        :example => '.... . .-.. .-.. --- / .-- --- .-. .-.. -..' }],
      
      'rot13' => :rot13,
      'sha1' => [lambda { |e, data| Digest::SHA1.hexdigest(data) }, { :help => 'Create a sha1 hash of some text' }],
      'sha256' => [lambda { |e, data| Digest::SHA256.hexdigest(data) }, { :help => 'Create a sha256 hash of some text' }],
      'md5' => [lambda { |e, data| Digest::MD5.hexdigest(data) }, { :help => 'Create a md5 hash of some text' }],
      'base64' => [lambda { |e, data| Base64.b64encode(data) }, { :help => 'Encode a string as base64' }],
      'decode64' => [lambda { |e, data| Base64.decode64(data) }, { :help => 'Decode a string with base64' }],
    }
  end
  
  def morse(e, data)
    data.downcase.split('').map{ |c| MORSE.index(c) }.join(' ')
  end
  
  def demorse(e, data)
    data.split(' ').map{ |m| MORSE.fetch(m, '-') }.join
  end
  
  def rot13(e, data)
    data.tr('A-Ma-mN-Zn-z', 'N-Zn-zA-Ma-m')
  end
end

Plugin.define do
  name 'security'
  description 'Hashes, morse code and base64.'
  object Security
end
