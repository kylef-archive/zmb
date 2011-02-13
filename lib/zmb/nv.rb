module ZMB
  module NV # (Non-volatile memory)
    def nv(key, value=nil, write=true)
      load_nv if @nv.nil?

      if value.nil?
        @nv[key]
      else
        @nv[key] = value
        save_nv if write
      end
    end

    # Gets a Boolean determining if the key is stored in NV
    #
    # key - String
    #
    # Returns a Boolean.
    def nv?(key)
      load_nv if @nv.nil?
      @nv.has_key?(key)
    end

    # Remove a value from the non-volatile memory
    #
    # key - String
    #
    # Returns the deleted value or nil if it didn't exist. 
    def nv!(key, write=true)
      load_nv if @nv.nil?
      ret = @nv.delete(key)
      save_nv if write
      ret
    end

    # Returns the location of the NV file
    def nv_file
      File.join(directory, 'nv.json')
    end

    # Load the NV from the nv file
    def load_nv
      if File.exists?(nv_file)
        @nv = JSON.parse(File.read(nv_file))
      else
        @nv = Hash.new
      end
    end

    # Save the current NV to the NV file
    def save_nv
      @nv = Hash.new unless @nv

      File.open(nv_file, 'w') do |f|
        f.write(@nv.to_json)
      end
    end
  end
end
