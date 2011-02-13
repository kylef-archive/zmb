module ZMB
  module NV # (Non-volatile memory)
    # Get / Save
    def nv(key, value=nil, write=true)
      load_nv if @nv.nil?

      if value.nil?
        @nv[key]
      else
        @nv[key] = value
        save_nv if write
      end
    end

    def nv?(key)
      load_nv if @nv.nil?
      @nv.has_key?(key)
    end

    # Delete
    def nv!(key, write=true)
      load_nv if @nv.nil?
      ret = @nv.delete(key)
      save_nv if write
      ret
    end

    def nv_file # Returns the location of the NV file
      File.join(directory, 'nv.json')
    end

    def load_nv
      if File.exists?(nv_file)
        @nv = JSON.parse(File.read(nv_file))
      else
        @nv = Hash.new
      end
    end

    def save_nv
      @nv = Hash.new unless @nv

      File.open(nv_file, 'w') do |f|
        f.write(@nv.to_json)
      end
    end
  end
end
