module SMTP
  module Server
    #
    # Handler for socket based SMTP connections
    #
    class SocketHandler
      
      include SMTP::Server::Protocol
      
      def self.handle_connection(socket)
        handler = new(socket)
        handler.handle_connection
      end
      
      def initialize(socket)
        @socket = socket
      end
      
      def handle_connection
        begin
          if start_session(@socket.peeraddr[3])
            pump_lines
          end
        ensure
          @socket.close
        end
      end
      
      def pump_lines
        while line = get_line
          more = process_line(line)
          break unless more
        end
      end
      
      if RUBY_VERSION =~ /1.9/ then
        def get_line
          line = @socket.gets("\n", 1000)
          line.chomp! if line
        end
      else
        def get_line
          line = @socket.gets
          # Errno::ECONNRESET
          line.chomp! if line
        end
      end
      
      def write(data)
        @socket.write(data)
      end

      def start_tls
        # todo
      end
      
    end
  end
end
