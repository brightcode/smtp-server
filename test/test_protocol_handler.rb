require 'test/unit'
require 'smtp-server'

class TestProtocolHandler < Test::Unit::TestCase

  class ProtocolHandler
    attr_reader :response
    
    include SMTP::Server::Protocol
    
    def write(response)
      @response = response
    end
  end
  
  def setup
    @handler = ProtocolHandler.new
    @handler.start_session("1.2.3.4")
  end
  
  def test_banner
    assert_response(/^220 ([\w-]+\.)+\w+ ESMTP/)
    command("QUIT")
    assert_response(/^221/)
  end

  def test_helo
    banner = response
    command "HELO example.com"
    assert_response(/^250 ([\w-]+\.)+\w+/)
    command "QUIT"
    response
  end

  def test_helo_empty
    banner = response
    command "HELO"
    assert_response(/^501/)
    command "QUIT"
    response
  end

  def test_helo_not_fqdn
    banner = response
    command "HELO foo"
    assert_response(/^250/)
    command "QUIT"
    response
  end
  
  def test_send_mail
    banner = response
    command "EHLO example.com"
    response
    command "MAIL FROM:<foo@example.com>"
    response
    command "RCPT TO:<bar@example.com>"
    assert_response(/^250/)
    command "DATA"
    assert_response(/^354/)
    @handler.process_line "From: foo@example.com"
    @handler.process_line "To: bar@example.com"
    @handler.process_line "Subject: test"
    @handler.process_line ""
    @handler.process_line "This is a test mail. Please ignore."
    @handler.process_line "."
    assert_response(/^250/)
    command "QUIT"
    response
  end

  def test_invalid_command
    banner = response
    1.times do
      command "TITA"
      assert_response(/^500/)
    end
    command "QUIT"
    response
  end

  def test_ehlo_empty
    banner = response
    command "EHLO"
    assert_response(/^501/)
    command "QUIT"
    response
  end

  def test_ehlo
    banner = response
    command "EHLO localhost.localdomain"
    assert_response(/^250/)
    command "QUIT"
    response
  end

  def test_mail_before_helo
    banner = response
    command "MAIL FROM:<>"
    assert_response(/^[25]/)
    command "QUIT"
    response
  end

  def test_mail_1
    banner = response
    command "EHLO localhost.localdomain"
    response
    command "MAIL"
    assert_response(/^501/)  
    command "QUIT"
    response
  end

  def test_mail_2
    banner = response
    command "EHLO localhost.localdomain"
    response
    command "MAIL:"
    assert_response(/^500/)  # syntax error is 500 cq 5.5.2
    command "QUIT"
    response
  end

  def test_mail_3
    banner = response
    command "EHLO localhost.localdomain"
    response
    command "MAIL FROM:"
    assert_response(/^501/)  
    command "QUIT"
    response
  end

  def test_mail_4
    banner = response
    command "EHLO localhost.localdomain"
    response
    command "MAIL FROM:test@foo.bar"
    assert_response(/^250/)  
    command "QUIT"
    response
  end

  def test_mail_5
    banner = response
    command "EHLO example.com"
    response
    command "MAIL FROM: test@foo.bar"
    assert_response(/^250/)  
    command "QUIT"
    response
  end
  
  # todo: syntax error in address

  def test_mail_null_sender
    banner = response
    command "EHLO example.com"
    response
    command "MAIL FROM:<>"
    assert_response(/^250/)  
    command "QUIT"
    response
  end

  def test_rcpt_before_mail
    banner = response
    command "EHLO example.com"
    response
    command "RCPT TO:<postmaster@example.com>"
    assert_response(/^503/)
    command "QUIT"
    response
  end

  def test_data_before_rcpt
    banner = response
    command "EHLO example.com"
    response
    command "MAIL FROM:<>"
    response
    command "DATA"
    assert_response(/^503/)
    command "QUIT"
    response
  end

  def test_mail_after_rcpt
    banner = response
    command "EHLO example.com"
    response
    command "MAIL FROM:<foo@bar.com>"
    response
    command "RCPT TO:<postmaster@localhost.localdomain>"
    response
    command "MAIL FROM:<foo@bar.com>"
    assert_response(/^503/)
    command "QUIT"
    response
  end

  #
  # helpers
  #
  
  def command(command)
    STDERR.puts ">> " + command
    @handler.process_line(command)
  end
  
  def response
    @handler.response
  end
  
  def assert_response(match)
    r = response
    STDERR.puts "<< " + r
    if match.instance_of?(Regexp)
      assert(r.match(match), "/#{match.source}/ expected but was #{r.inspect}")
    else
      assert_equal(match, r)
    end
  end
  
end
