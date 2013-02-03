module SMTP
  module Server
    #
    # SMTP server protocol implementation
    # provided as a module so it can be included in classes that need to inherit from a server framework class
    # the protocol contains state, and one instance must be used per connection
    # advertises STARTTLS if start_tls method is provided by user object
    # advertises AUTH PLAIN LOGIN if authenticate method is provided by user object
    # advertises SIZE if max_size method is provided by user object
    #
    module Protocol
      
      include SMTP::Server::CallbackStubs
      
      # to be called after client connected
      # client_connection may be overriden to accept/reject based on client ip
      # connection should be closed if false is returned
      def start_session(ip)
        @state = []
        if client_connection(ip)
          reply 220, "#{get_server_domain} ESMTP service ready"
          true
        else
          reply 554, "#{get_server_domain} No SMTP service for you [#{ip}] here"
          false  # close connection after writing
        end
      end

      # to be called on each line received from client
      # returns true when session in progress and false when QUIT is given
      def process_line(line)
        if @state.include?(:data)
          process_data_line(line)
        elsif @state.include?(:auth_plain_incomplete)
          process_auth_plain_line(line)
        elsif @state.include?(:auth_login_incomplete)
          process_auth_login_line(line)
        else
          process_command_line(line)
        end
        !@state.include?(:quit) # return true unless QUIT is given
      end
      
      def process_command_line(line)
        # split command at first space, if present
        command, rest = line.split(' ', 2)
        case command.upcase
        when 'EHLO'
          process_ehlo rest
        when 'HELO'
          process_helo rest
        when 'STARTTLS'
          process_starttls
        when 'AUTH'
          process_auth rest
        when 'MAIL'
          rest.slice!(/^FROM: ?/i) if rest
          process_mail_from rest
        when 'RCPT'
          rest.slice!(/^TO: ?/i) if rest
          process_rcpt_to rest
        when 'DATA'
          process_data
        when 'RSET'
          process_expn
        when 'QUIT'
          process_quit
        when 'VRFY'
          process_vfy
        when 'EXPN'
          process_expn
        when 'HELP'
          process_help
        when 'NOOP'
          process_noop
        else
          process_unknown
        end
      end
      
      #--
      # EHLO/HELO is always legal, per the standard. On success
      # it always clears buffers and initiates a mail "transaction."
      # Which means that a MAIL FROM must follow.
      #
      # Per the standard, an EHLO/HELO or a RSET "initiates" an email
      # transaction. Thereafter, MAIL FROM must be received before
      # RCPT TO, before DATA. Not sure what this specific ordering
      # achieves semantically, but it does make it easier to
      # implement. We also support user-specified requirements for
      # STARTTLS and AUTH. We make it impossible to proceed to MAIL FROM
      # without fulfilling tls and/or auth, if the user specified either
      # or both as required. We need to check the extension standard
      # for auth to see if a credential is discarded after a RSET along
      # with all the rest of the state. We'll behave as if it is.
      # Now clearly, we can't discard tls after its been negotiated
      # without dropping the connection, so that flag doesn't get cleared.
      #
      def process_ehlo domain
        if domain !~ /[\w.-]+/
          reply 501, "Syntax: EHLO hostname"
        elsif receive_ehlo_domain domain
          params = [get_server_domain]
          params << "STARTTLS" if respond_to?(:start_tls)
          params << "AUTH PLAIN LOGIN" if respond_to?(:authenticate)
            # Multiple values for the keyword AUTH are allowed by RFC 1869, 
            # however broke the parsing of several ESMTP client implementations. 
            # A work around is, to add artificially a "=" (equal sign) between the AUTH keyword and the value.
            #send_data "250-AUTH=PLAIN"  # ? LOGIN CRAM-MD5
          params << "SIZE #{max_size}" if respond_to?(:max_size)
          params << "PIPELINING"
          params << "8BITMIME"
          #params << "ENHANCEDSTATUSCODES"
          reply 250, params
          reset_protocol_state
          @state << :ehlo
        else
          reply 550, "Requested action not taken"
        end
      end

      def process_helo domain
        if domain !~ /[\w.-]+/
          reply 501, "Syntax: HELO hostname"
        elsif receive_ehlo_domain domain
          reply 250, get_server_domain
          reset_protocol_state
          @state << :ehlo
        else
          reply 550, "Requested action not taken"
        end
      end

      #--
      # STARTTLS may not be issued before EHLO, or unless the user has chosen
      # to support it.
      # TODO, must support user-supplied certificates.
      #
      def process_starttls
        if options[:starttls]
          if @state.include?(:starttls)
            reply 503, "TLS Already negotiated"
          elsif !@state.include?(:ehlo)
            reply 503, "EHLO required before STARTTLS"
          else
            reply 220, "Start TLS negotiation"
            start_tls
            # Upon completion of the TLS handshake, the SMTP protocol is reset to the initial state 
            # (the state in SMTP after a server issues a 220 service ready greeting). The list of 
            # SMTP service extensions returned in response to an EHLO command received after the TLS 
            # handshake MAY be different than the list returned before the TLS handshake.
            @state << :starttls
          end
        else
          process_unknown
        end
      end

      #--
      # Process AUTH command. So far, AUTH PLAIN and AUTH LOGIN are supported.
      #
      # PLAIN authentication is efficient in that it requires only a single command and response. 
      # Unless an encrypted SMTP connection is used, the data travels over the network unencryopted, 
      # and is vulnerable to eavesdropping. 
      #
      # LOGIN authentication is not described by any RFC, but it is used by the user agent Pine, some 
      # versions of Outlook and Netscape, and maybe others. LOGIN authentication is less efficient 
      # than PLAIN, because three interactions are required. 
      # 
      # TODO: CRAM-MD5 authentication avoids transmitting unexncrypted passwords over the network. The 
      # disadvantage is that the password must be held unencrypted on the server as well as on the client.
      #
      def process_auth str
        if @state.include?(:auth)
          reply 503, "auth already issued"
        elsif str =~ /\APLAIN\s?/i
          if $'.length == 0
            # we got a partial response, so let the client know to send the rest
            # There is a common misconception that the data has to be sent with the AUTH command
            @state << :auth_plain_incomplete
            reply 334, ""
          else
            # we got the initial response, so go ahead & process it
            process_auth_plain_line($')
          end
        elsif str =~ /\ALOGIN\s?/i
          if $'.length == 0
             @state << :auth_login_incomplete
             reply 334, "VXNlcm5hbWU6"  # 'Username:' in Base64
           else
             process_auth_login_line($')
           end
        #elsif str =~ /\ACRAM-MD5/i
        else
          reply 504, "auth mechanism not available"
        end
      end

      def process_auth_plain_line(line)
        plain = line.unpack("m").first
        # The client sends the authorization identity (identity to login as), 
        # followed by a US-ASCII NULL character, followed by the authentication 
        # identity (identity whose password will be used), followed by a US-ASCII 
        # NULL character, followed by the clear-text password. The client may 
        # leave the authorization identity empty to indicate that it is the same 
        # as the authentication identity.
        _, user, pass = plain.split("\000")
        process_plain_auth(user, pass)
        @state.delete :auth_plain_incomplete
      end

      def process_auth_login_line(line)
        @login_auth ||= []
        @login_auth << line.unpack("m").first
        if @login_auth.size == 2
          process_plain_auth(@login_auth.shift, @login_auth.shift)
          @state.delete :auth_login_incomplete
        else
          reply 334, "UGFzc3dvcmQ6"  # 'Password:' in Base64
        end
      end

      # process authentication parameters
      # calls receive_plain_auth with user and password
      def process_plain_auth(user, password)
        if receive_plain_auth(user, password)
          reply 235, "authentication ok"
          @state << :auth
        else
          reply 535, "invalid authentication"
        end
      end

      # handle MAIL FROM:
      # calls receive_sender with provided address and optional parameters
      def process_mail_from sender
        # Requiring TLS is touchy, cf RFC2784.
        # Requiring AUTH seems to be much more reasonable.
        #if (options[:starttls] == :required and !@state.include?(:starttls))
        #  reply 550, "This server requires STARTTLS before MAIL FROM"
        #elsif (options[:auth] == :required and !@state.include?(:auth))
        #  reply 550, "This server requires authentication before MAIL FROM"
        if @state.include?(:mail_from)
          reply 503, "Sender already given"
        elsif sender !~ /@|<>/  # valid email or empty sender (<>)
          reply 501, "Syntax: MAIL FROM:<address>"
        elsif !receive_sender(sender)
          reply 550, "sender is unacceptable"
        else
          reply 250, "Ok"
          @state << :mail_from
        end
      end

      # handle RCPT TO:
      # calls receive_recipient with provided address and optional parameters
      def process_rcpt_to recipient
        # Since we require :mail_from to have been seen before we process RCPT TO,
        # we don't need to repeat the tests for TLS and AUTH.
        if !@state.include?(:mail_from)
          reply 503, "No sender given"
        elsif recipient !~ /^<?[^>]+>?/
          reply 501, "Syntax: RCPT TO:<address>"
        elsif !receive_recipient(recipient)
          reply 550, "recipient is unacceptable"  # or too many recipients
        else
          reply 250, "Ok"
          @state << :rcpt unless @state.include?(:rcpt)
        end
      end

      # handle DATA
      def process_data
        if !@state.include?(:rcpt)
          reply 503, "No valid recipients"
        else
          receive_data_command
          reply 354, "End data with <CR><LF>.<CR><LF>"
          @state << :data
        end
      end

      # process line after DATA
      # calls receive_data_line until data is complete
      # calls receive_message if message is complete
      def process_data_line line
        if line == "."
          if receive_message
            reply 250, "Message accepted"
          else
            reply 550, "Message rejected"
          end
          # do not allow another DATA with same sender and recipients
          # allow another transaction without requiring RSET
          @state -= [:data, :mail_from, :rcpt]
        else
          # slice off leading . if any
          line.slice!(0...1) if line[0] == ?.
          receive_data_line(line)
        end
      end

      def process_rset
        reset_protocol_state
        reply 250, "OK"
      end

      def process_quit
        @state << :quit
        reply 221, "#{get_server_domain} closing connection"
      end

      # TODO - implement this properly, the implementation is a stub!
      def process_vrfy
        # A server MUST NOT return a 250 code in response to a VRFY or EXPN
        # command unless it has actually verified the address.
        reply 502, "Command not implemented"
      end

      # TODO - implement this properly, the implementation is a stub!
      def process_help
        reply 502, "Command not implemented"
      end

      # TODO - implement this properly, the implementation is a stub!
      def process_expn
        reply 502, "Command not implemented"
      end

      def process_noop
        reply 250, "OK"
      end

      def process_unknown
        reply 500, "unrecognized command"
      end

      #
      # helper functions
      #

      #--
      # This is called at several points to restore the protocol state
      # to a pre-transaction state. In essence, we "forget" having seen
      # any valid command except EHLO and STARTTLS.
      # We also have to callback user code, in case they're keeping track
      # of senders, recipients, and whatnot.
      #
      # We try to follow the convention of avoiding the verb "receive" for
      # internal method names except receive_line (which we inherit), and
      # using only receive_xxx for user-overridable stubs.
      #
      # init_protocol_state is called when we initialize the connection as
      # well as during reset_protocol_state. It does NOT call the user
      # override method. This enables us to promise the users that they
      # won't see the overridable fire except after EHLO and RSET, and
      # after a message has been received. Although the latter may be wrong.
      # The standard may allow multiple DATA segments with the same set of
      # senders and recipients.
      #
      def reset_protocol_state
        # clear state except ehlo and starttls
        s,@state = @state,[]
        @state << :starttls if s.include?(:starttls)
        @state << :ehlo if s.include?(:ehlo)
      end

      def reply(code, message)
        if message.is_a?(Array)
          last = message.pop # remove last element
          lines = message.map {|param| "#{code}-#{param}\r\n"}
          write lines.join + "#{code} #{last}\r\n"
        else
          write "#{code} #{message}\r\n"
        end
      end
    end
  end
end
