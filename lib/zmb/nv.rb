require 'json'

module ZMB
  class NVHash <Hash
    def self.from_file(nv_file)
      nv = new(nv_file)

      if File.exists?(nv_file)
        nv.update(JSON.parse(File.read(nv_file)))
      end

      nv
    end

    def initialize(nv_file)
      @nv_file = nv_file
    end

    def save
      File.open(@nv_file, 'w') do |f|
        f.write(to_json)
      end
    end

    def key(key, default=nil)
      if key?(key)
        self[key]
      else
        default
      end
    end

    def []=(key, value)
      super
      save
    end

    def delete(key)
      super
      save
    end
  end

  module NV # (Non-volatile memory)
    # Returns a NVHash for self
    def nv
      @nv || nv!
    end

    # Returns a new NVHash
    def nv!
      @nv = NVHash.from_file(File.join(config_dir, 'nv.json'))
    end
  end
end
