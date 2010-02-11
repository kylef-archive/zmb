class Zmb
  require 'socket'
  
  def initialize
    @plugins = {'core/zmb' => self}
    @sockets = Hash.new
  end
  
  def run
    begin
      while 1
        socket_select(timeout)
      end
    rescue Interrupt
      return
    end
  end
  
  def timeout
    60.0
  end
  
  def socket_add(delegate, socket)
    @sockets[socket] = delegate
  end
  
  def socket_delete(item)
    if @sockets.include?(item) then
      @sockets.select{|sock, delegate| delegate == item}.each{|key, value| @sockets.delete(key)}
    end
    
    if @sockets.has_key?(item) then
      @sockets.delete(item)
    end
  end
  
  def socket_select(timeout)
    result = select(@sockets.keys, nil, nil, timeout)
    
    if result != nil then
      result[0].select{|sock| @sockets.has_key?(sock)}.each do |sock|
        if sock.eof? then
          @sockets[sock].disconnected(self, sock) if @sockets[sock].respond_to?('disconnected')
          socket_delete sock
        else
          @sockets[sock].received(self, sock, sock.gets()) if @sockets[sock].respond_to?('received')
        end
      end
    end
  end
end