module IRC
  class ISupport <Hash
    class << self
      def mappings
        @mappings || Hash.new
      end

      def map(keys, &block)
        @mappings ||= Hash.new
        keys = [keys] unless keys.respond_to?(:each)
        keys.each do |key|
          @mappings[key] = block
        end
      end
    end

    def evaluate(key, value)
      if self.class.mappings.has_key?(key)
        self[key] = self.class.mappings[key].call(value)
      end
    end

    map :prefix do |v|
      h = {}
      modes, prefixes = v.match(/^\((.+)\)(.+)$/)[1..2]
      modes.split('').each_with_index do |c, i|
        h[c] = prefixes[i]
      end
      h
    end

    map [:chantypes, :statusmsg, :elist, :statusmsg] { |v| v.split('') }

    map [:modes, :maxchannels, :nicklen, :maxbans,
         :topiclen, :kicklen, :channellen, :chidlen,
         :silence, :awaylen, :maxtargets, :watch, :topiclen] { |v| v.to_i }

    map [:std] { |v| v.split(',') }

    map [:casemapping] { |v| v.to_sym }

    map [:name] { |v| v }

    map :chanmodes do |v|
      h = {}
      a, b, c, d = v.split(',').map{ |a| a.split('') }
      a.each{ |x| h[x] = 'a' } if a
      b.each{ |x| h[x] = 'b' } if b
      c.each{ |x| h[x] = 'c' } if c
      d.each{ |x| h[x] = 'd' } if d
      h
    end

    map [:chanlimit, :maxlist, :idchan] do |v|
      h = {}
      v.split(',').each do |pair|
        args, num = pair.split(':')
        args.split('').each do |arg|
          h[arg] = num.to_i
        end
      end
      h
    end

    map :targmax do |v|
      h = {}
      v.split(',').each do |pair|
        key, value = pair.split(':')
        h[key] = value.to_i
      end
      h
    end

    map [:excepts] { |v| v.nil? ? 'e' : v }
    map [:invex] { |v| v.nil? ? 'I' : v }
    map [:safelist] { |v| true }

    def initialize
      self[:casemapping] = :rfc1459
      self[:chanmodes] = {
        'b' => 'a',
        'e' => 'a',
        'I' => 'a',
        'k' => 'b',
        'l' => 'c',
        'p' => 'd',
        's' => 'd',
        't' => 'd',
        'i' => 'd',
        'n' => 'd',
      }
      self[:prefix] = { 'o' => '@', 'v' => '+' }
      self[:channellen] = 200
      self[:chantypes] = ['#', '&']
      self[:modes] = 3
      self[:nicklen] = 9
      self[:statusmsg] = []
      self[:std] = []
      self[:targmax] = {}
      self[:excepts] = false
      self[:idchan] = {}
      self[:invex] = false
      self[:maxlist] = {}
      self[:network] = nil
      self[:safelist] = false
      self[:statusmsg] = []

      # Unlimited
      self[:topiclen] = 1.0/0.0
      self[:kicklen] = 1.0/0.0
      self[:modes] = 1.0/0.0
    end

    def parse(line)
      line.split(' ').each do |options|
        key, value = options.split('=')
        evaluate(key.downcase.to_sym, value)
      end
    end
  end
end
