module SMTP
  module Server
    #
    # Handler for socket based SMTP connections
    #
    class Connection
      
      include SMTP::Server::Protocol
      
      def self.handler(socket)
        conn = new(socket)
        conn.handler
      end
      
      def initialize(socket)
        @socket = socket
      end
      
      def handler
        begin
          if start_session(@socket.peeraddr[3])
            while line = get_line
              more = process_line(line)
              break unless more
            end
          end
        ensure
          @socket.close
        end
      end
      
      if RUBY_VERSION =~ /1.9/ then
        def get_line
          # SMTP allows lines up to 1000 chars incl CRLF
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
