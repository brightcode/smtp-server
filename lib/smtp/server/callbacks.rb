module SMTP
  module Server
    #
    # Methods called by the protocol handler which can be overridden in user code
    #
    module Callbacks
      
      # Called when new client connection is made. 
      # Return true (default) to accept the client ip, or return false to reject the 
      # client with a 554 error. 
      def client_connection ip
        true
      end

      # The domain name returned in the response of the HELO, EHLO, and QUIT command.
      # Default set to Socket#gethostname.
      def get_server_domain
        @hostname ||= Socket.gethostname
      end

      # Called when the HELO or EHLO command is received with the remote domain
      # provided by the client. Return true (default) to accept the domain or return
      # false to reject the domain with 550.
      def receive_ehlo_domain domain
        true
      end
      
      # Return true or false to indicate that the authentication is acceptable.
      #def authenticate user, password
      #  true
      #end

      # Called when a valid MAIL FROM command is given to pass the envelope sender. 
      # Return true to accept the sender or return false to reject the sender with 550.
      def receive_sender sender
        true
      end

      # Called when a valid RCPT TO command is given to pass a recipient.
      # Return true to accept the recipient or return false to reject the recipient with 550.
      def receive_recipient rcpt
        true
      end

      # Called to indicate that data phase is started. May be used to initialize data storage.
      def receive_data_command
      end
      
      # Called on each line of data. Line delimiters have been removed and lines
      # with a leading dot have been unescaped.
      def receive_data_line line
      end

      # Called when end of data is given. Return true to accept the message or return false
      # to reject the message with a 550 error.
      def receive_message
        true
      end
    end
  end
end
