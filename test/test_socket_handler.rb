require 'test/unit'
require 'smtp-server'
require 'net/smtp'

class TestSocketHandler < Test::Unit::TestCase
 
  HOST = '127.0.0.1'
  PORT = 10025
  
  class Handler < SMTP::Server::SocketHandler
    
    def receive_data_command
      @data = []
    end

    def receive_data_line(line)
      @data << line
    end

    def receive_message
      # reject message if it doesn't contain Hallo
      @data.join("\n") =~ /Hallo/
    end
  end
  
  def setup
    @thread = Thread.new do
      Thread.current.abort_on_exception = true
      server = TCPServer.new(HOST, PORT)
      Handler.handle_connection(server.accept)
    end
    sleep 1  # wait for server to startup
  end
  
  def teardown
    @thread.join
  end
  
  def test_net_smtp_client
    assert_nothing_raised do
      smtp = Net::SMTP.new(HOST, PORT)
      smtp.set_debug_output $stderr
      smtp.start(Socket.gethostname) do
        smtp.send_mail("From: <maarten>\r\n\r\nHallo", 'foo@example.com', 'bar@example.com')
      end
    end
  end
 
end
