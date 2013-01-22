require 'smtp/server/connection'

module SMTP
  class Server
    def initialize(host, port)
      @server = TCPServer.new(host, port)
    end
    
    def close
      # MRI 1.8/JRuby: raises #<IOError: stream closed> in accept
      # MRI 1.9: raises #<Errno::EBADF: Bad file descriptor> in accept
      @server.close  
    end
    
    def run
      while socket = accept
        on_connection(socket)
      end
    end
    
    def accept
      begin
        @server.accept
      rescue # server closed
        raise unless @server.closed?
        nil
      end
    end
    
    def on_connection(socket)
      Connection.new(socket).handle
    end
  end
end
