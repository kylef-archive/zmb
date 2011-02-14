module ZMB
  class Halt <Exception; end
  class HaltCore <Halt; end

  # This module requires `plugins` to return a list of all loaded plugins
  module Plugins
    def plugin(symbol)
      plugins.find{ |p| p.class.name == symbol }
    end

    def plugin!(name)
      plugin(name.to_sym)
    end

    def halt(*args)
      raise Halt.new(*args)
    end

    def haltcore(*args)
      raise HaltCore.new(*args)
    end

    def post(signal, *args, &block)
      plugins.select{ |p| p.respond_to?(signal) }.each do |p|
        begin
          p.send(signal, *args)
        rescue HaltCore
          block.call if block
          return
        rescue Halt
          return
        rescue
          zmb.debug(p, "Sending signal `#{signal}` failed", $!)
        end
      end
    end
  end
end
