# SMTP::Server

Framework independent SMTP server protocol implemenation. It can be used in threaded solutions such as GServer or Celluliod. But it works just as well in evented solutions, such as EventMachine, Netty or VertX.

The user of the protocol handler module (parent or including class) should frame incoming data into lines and pass them to the handler. The user should also provide a write method that is used by the handler to return responses.

The protocol handler includes callback stub methods which can be overridden by the parent to save or reject the following items: connection ip, authentication credentials, envelope sender, envelope recipient and message.

The protocol handler supports the following SMTP extensions: STARTTLS, AUTH PLAIN, AUTH LOGIN, and PIPELINING. STARTTLS is advertised if a start_tls method is provided by the user. AUTH is advertised if an authenticate method is provided by the user.

A connection handler class is provided which further simplifies the implementation on top of a client connection socket. It includes the protocol handler passes IO to and from the handler, so only the necessary callbacks need to be implemented.

## Installation

Add this line to your application's Gemfile:

    gem 'smtp-server'

And then execute:

    bundle

Or install it yourself as:

    gem install smtp-server

## Usage

A threaded SMTP server based on GServer; it can't get any easier:

    class SmtpServer < GServer
    
      class SmtpServerConnection < SMTP::Server::Connection
        # implement callbacks as needed
      end

      def serve(socket)
        SmtpServerConnection.handler(socket)
      end
    end

SMTP server in EventMachine with several improvements over EventMachine::Protocols::SmtpServer:

    class SmtpServerConnection < EM::Protocols::LineAndTextProtocol
    
      include SMTP::Server::Protocol
      
      def post_init
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        if !start_session(ip)
          close_connection_after_writing
        end
      end

      def receive_line(line)
        if !process_line(line)
          close_connection_after_writing
        end
      end
      
      def write(data)
        send_data(data)
      end
      
      # implement callbacks as needed
    end
    
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
