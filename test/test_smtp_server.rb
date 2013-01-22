require 'test/unit'
require 'smtp-server'
require 'net/smtp'

class TestSmtpServer < Test::Unit::TestCase
 
  HOST = '127.0.0.1'
  PORT = 10025
  
  def setup
    @thread = Thread.new do 
      @server = SMTP::Server.new(HOST, PORT)
      @server.run
      STDERR.puts "finished run"
    end
    sleep 1  # wait for server to startup
  end
  
  def teardown
    STDERR.puts "close server..."
    @server.close
    STDERR.puts "join thread..."
    @thread.join(5)  # wait with 5 second timeout
  end
 
  def test_disconnect
    assert_nothing_raised do
      socket = TCPSocket.open(HOST, PORT)
      socket.gets # read banner
      socket.close
    end
  end
 
  def test_net_smtp_client
    assert_nothing_raised do
      smtp = Net::SMTP.new(HOST, PORT)
      smtp.set_debug_output $stderr
      smtp.start(Socket.gethostname) do
        smtp.send_mail("From: <maarten>\r\nHallo", 'postmaster', 'postmaster')
      end
    end
  end
 
end
