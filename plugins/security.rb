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
  def initialize(sender, s)
    
  end
  
  def settings
    { 'plugin' => 'security' }
  end
  
  def commands
    {
      'morse' => [:morse, 1, {
        :help => 'Encode text into morse code',
        :example => 'Hello World' }],
      'decode-morse' => [:demorse, 1, {
        :help => 'Convert morse code into text',
        :example => '.... . .-.. .-.. --- / .-- --- .-. .-.. -..' }],
      
      'rot13' => :rot13,
      'sha1' => [:sha1, 1, { :help => 'Create a sha1 hash of some text' }],
      'sha256' => [:sha256, 1, { :help => 'Create a sha256 hash of some text' }],
      'md5' => [:md5, 1, { :help => 'Create a md5 hash of some text' }],
      'base64' => [:base64, 1, { :help => '' }],
      'decode64' => [:decode64, 1, { :help => '' }],
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
  
  def sha1(e, data)
    Digest::SHA1.hexdigest(data)
  end
  
  def sha256(e, data)
    Digest::SHA256.hexdigest(data)
  end
  
  def md5(e, data)
    Digest::MD5.hexdigest(data)
  end
  
  def base64(e, data)
    Base64.b64encode(data)
  end
  
  def decode64(e, data)
    Base64.decode64(data)
  end
end

Plugin.define do
  name 'security'
  description 'Hashes, morse code and base64.'
  object Security
end
