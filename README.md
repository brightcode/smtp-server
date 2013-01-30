# SMTP::Server

Simple SMTP server for receiving mails from trusted sources. For example in a Postfix content filter.

## Installation

Add this line to your application's Gemfile:

    gem 'smtp-server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install smtp-server

## Usage

Single threaded

    server = SMTP::Server.new(host, port)
    server.run do |socket|
      connection = SMTP::Server::Connection.new(socket)
      connection.handle do |sender, recipients, message|
        puts "message from: #{sender} to #{recipients.join(',')}"
      end
    end

Concurrent connections

    server = SMTP::Server.new(host, port)
    server.run do |socket|
      Thread.new(socket) do |socket|
        connection = SMTP::Server::Connection.new(socket)
        connection.handle do |sender, recipients, message|
          puts "message from: #{sender} to #{recipients.join(',')}"
        end
      end
    end

Acceptor thread and connection threads
    
    Thread.new do
      begin
        @server = SMTP::Server.new(@host, @port)
        @server.run do |socket|
          Thread.new do
            begin
              connection = SMTP::Server::Connection.new(socket)
              connection.handle do |sender, recipients, message|
                puts "message from: #{sender} to #{recipients.join(',')}"
              end
            rescue
              STDERR.puts $!.to_s
            end
          end
        end
      rescue
        STDERR.puts $!.to_s
      end
    end
    
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
