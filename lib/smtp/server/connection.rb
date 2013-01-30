require 'socket'

module SMTP
  class Server
    
    class Connection
      
      def initialize(socket)
        @socket = socket
        @state = nil
      end

      def close
        @socket.close
      end

      def handle(&block)
        @block = block if block_given?
        begin
          STDERR.puts "banner"
          # send banner greeting
          reply 220, "#{hostname} ESMTP"
          while line = getline  # nil when peer disconnected
            # split command and parameters at first <SP>
            command, params = line.rstrip.split(' ', 2)
            on_command(command, params)
            break if @state == :quit
          end
        ensure
          close
        end
      end
      
      if RUBY_VERSION =~ /1.9/ then
        def getline
          line = @socket.gets("\n", 1000)
          line.chomp! if line
        end
      else
        def getline
          line = @socket.gets
          line.chomp! if line
        end
      end
      
      def on_command(command, params)
        # dispatch command
        case command.upcase
        when 'HELO'
          on_helo(params)
        when 'EHLO'
          on_ehlo(params)
        when 'MAIL'
          params.slice!(/^FROM: ?/i) if params
          on_mail(params)
        when 'RCPT'
          params.slice!(/^TO: ?/i) if params
          on_rcpt(params)
        when 'DATA'
          on_data
        when 'RSET'
          on_rset
        when 'QUIT'
          on_quit
        else
          reply "500 unrecognized command"
        end
      rescue => e
        $stderr.puts e.to_s
        $stderr.puts e.backtrace.join("\n")
        reply "451 #{e.to_s}"
      end
      
      def on_helo(domain)
        #if domain !~ /[\w.-]+/
        #  reply "501 Syntax: HELO hostname"
        #  return
        #end
        
        @heloname = domain
        reply 250, hostname
      end

      def on_ehlo(domain)
        if domain !~ /[\w.-]+/
          reply "501 Syntax: HELO hostname"
          return
        end
        
        @heloname = domain
        reply 250, hostname, 'PIPELINING', '8BITMIME'
      end

      def on_mail(params)
        # mail is allowed after helo, rset or end of data  
        if @state != nil && @state != :helo
          reply 503, "5.5.1 Error: nested MAIL command"
          return
        end

        address = parse_address(params)
        if address.nil?
          reply "501 5.5.4 Syntax: MAIL FROM:<address>"
          return
        end

        # start new transaction
        @sender = address
        @recipients = []
        reply 250, "2.1.0 Ok"
      end

      def on_rcpt(params)
        if @sender.nil?
          reply 503, "5.5.1 Error: need MAIL command"
          return
        end

        address = parse_address(params)
        if address.nil? || address.empty?
          reply "501 5.5.4 Syntax: RCPT TO:<address>"
          return
        end

        @recipients << address
        reply 250, "2.1.5 Ok"
      end

      def on_data
        if @recipients.nil? || @recipients.empty?
          reply 503, "5.5.1 Error: no valid recipients"
          return
        end

        @data = []
        reply 354, "End data with <CR><LF>.<CR><LF>"

        # optimization since we are in a dedicated thread
        loop do 
          line = getline
          raise EOFError if line.nil?
          break if line == "."
          line.slice!(0...1) if line[1] == ?.
          #if (@data.length + line.length) > MAX_SIZE
          #  @state = :helo  # ?
          #  reply "550 Message too large"  # !proper message
          #  return
          #end
          @data << line
        end
        
        @block.call(@sender, @recipients, @data.join("\n")) if @block
        
        # transaction finished
        @sender = nil
        @recipients = nil
        @data = nil
        reply 250, "2.0.0 Ok"  # queued as %s
      end

      def on_rset
        # abort transaction and restore state to right after HELO/EHLO
        @sender = nil
        @recipients = nil
        @data = nil
        reply 250, "2.0.0 Ok"
      end

      def on_quit
        @state = :quit
        reply 221, "#{hostname} closing connection"
      end

      def hostname
        @hostname ||= Socket.gethostname
      end

      private

      def parse_address(params)
        if params
          params[/<?([^> ]*)>?/, 1]
        end
      end

      def reply(*args)
        code = args.shift.to_s # remove first element
        last = args.pop # remove last element
        if args.empty?
          @socket.write("#{code} #{last}\r\n")
        else
          resp = args.inject("") do |resp, value|
            resp << "#{code}-#{value}\r\n"
          end
          resp << "#{code} #{last}\r\n"
          @socket.write(resp)
        end
      end
      
    end
  end
end
