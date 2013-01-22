require 'test/unit'
require 'smtp-server'
require 'net/smtp'

class TestSmtpServer < Test::Unit::TestCase
 
 def test_smoke
   server = nil
   thread = Thread.new do 
     server = SMTP::Server.new('127.0.0.1', 10025)
     server.run
   end
   #server.close
   thread.join
   assert(true)
 end
 
end
