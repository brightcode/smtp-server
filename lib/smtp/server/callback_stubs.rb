module SMTP
  module Server
    #
    # Everything in here can be overridden in user code
    #
    module CallbackStubs
      
      # Called when new client connection is made. A true response (default) will 
      # return a normal banner greeting. A false response will return a 554 error 
      # and disconnect.
      def client_connection ip
        true
      end

      # The domain name returned in the response of the HELO, EHLO, and QUIT command.
      # Default set to Socket#gethostname.
      def get_server_domain
        Socket.gethostname
      end

      # Called when the HELO or EHLO command is received with the remote domain
      # provided by the client. A true response (default) will return a normal
      # response. A false response will cause a 550 error to be returned to the 
      # remote client.
      def receive_ehlo_domain domain
        true
      end
      
      # Return true or false to indicate that the authentication is acceptable.
      #def authenticate user, password
      #  true
      #end

      # Receives the argument of the MAIL FROM command. Return false to
      # indicate to the remote client that the sender is not accepted.
      # This can only be successfully called once per transaction.
      #
      def receive_sender sender
        true
      end

      # Receives the argument of a RCPT TO command. Can be given multiple
      # times per transaction. 
      # Use code should return true or false to indicate if the recipient is accepted or
      # return a Deferrable.
      def receive_recipient rcpt
        true
      end

      def receive_data_command
      end
      
      # Sent when data from the remote peer is available. The size can be controlled
      # by setting the :chunksize parameter. This call can be made multiple times.
      # The goal is to strike a balance between sending the data to the application one
      # line at a time, and holding all of a very large message in memory.
      #
      def receive_data_line line
      end

      # Sent after a message has been completely received. 
      # User code must either return true or false to indicate whether the message has
      # been accepted for delivery
      def receive_message
        true
      end
    end
  end
end
