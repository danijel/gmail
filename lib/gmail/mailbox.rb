module Gmail
  class Mailbox
    MAILBOX_ALIASES = {
      :all       => ['ALL'],
      :seen      => ['SEEN'],
      :unseen    => ['UNSEEN'],
      :read      => ['SEEN'],
      :unread    => ['UNSEEN'],
      :flagged   => ['FLAGGED'],
      :unflagged => ['UNFLAGGED'],
      :starred   => ['FLAGGED'],
      :unstarred => ['UNFLAGGED'], 
      :deleted   => ['DELETED'],
      :undeleted => ['UNDELETED'],
      :draft     => ['DRAFT'],
      :undrafted => ['UNDRAFT']
    }
  
    attr_reader :name
    attr_reader :external_name

    def initialize(gmail, name="INBOX")
      @name  = name
      @external_name = Net::IMAP.decode_utf7(name)
      @gmail = gmail
    end

    # Returns list of emails which meets given criteria. 
    #
    # ==== Examples
    #
    #   gmail.inbox.emails(:all)
    #   gmail.inbox.emails(:unread, :from => "friend@gmail.com")
    #   gmail.inbox.emails(:all, :after => Time.now-(20*24*3600))
    #   gmail.mailbox("Test").emails(:read)
    #
    #   gmail.mailbox("Test") do |box| 
    #     box.emails(:read)
    #     box.emails(:unread) do |email|
    #       ... do something with each email...
    #     end
    #   end
    def emails(*args, &block)
      args << :all if args.size == 0

      if args.first.is_a?(Symbol) 
        search = MAILBOX_ALIASES[args.shift].dup
        opts = args.first.is_a?(Hash) ? args.first : {}
        
        opts[:after]      and search.concat ['SINCE', opts[:after].to_imap_date]
        opts[:before]     and search.concat ['BEFORE', opts[:before].to_imap_date]
        opts[:on]         and search.concat ['ON', opts[:on].to_imap_date]
        opts[:from]       and search.concat ['FROM', opts[:from]]
        opts[:to]         and search.concat ['TO', opts[:to]]
        opts[:subject]    and search.concat ['SUBJECT', opts[:subject]]
        opts[:label]      and search.concat ['LABEL', opts[:label]]
        opts[:attachment] and search.concat ['HAS', 'attachment']
        opts[:search]     and search.concat ['BODY', opts[:search]]
        opts[:body]       and search.concat ['BODY', opts[:body]]
        opts[:message_id] and search.concat ['HEADER','MESSAGE-ID', opts[:message_id]]
        opts[:query]      and search.concat opts[:query]

        @gmail.mailbox(name) do
          @gmail.conn.uid_search(search).collect do |uid| 
            message = (messages[uid] ||= Message.new(self, uid))
            block.call(message) if block_given?
            message
          end
        end
      elsif args.first.is_a?(Hash)
        emails(:all, args.first)
      else
        raise ArgumentError, "Invalid search criteria"
      end
    end
    alias :mails :emails
    alias :search :emails
    alias :find :emails
    alias :filter :emails

    # This is a convenience method that really probably shouldn't need to exist, 
    # but it does make code more readable, if seriously all you want is the count 
    # of messages.
    #
    # ==== Examples
    #
    #   gmail.inbox.count(:all)
    #   gmail.inbox.count(:unread, :from => "friend@gmail.com")
    #   gmail.mailbox("Test").count(:all, :after => Time.now-(20*24*3600))
    def count(*args)
      @size = emails(*args).size
    end

    def size=(value)
      @size = value
    end

    # Initialy this is size received after selecting the mailbox
    # if you need to get size of mailbox after being logged for some time, use count
    def size
      @size
    end

    # This permanently removes messages which are marked as deleted
    def expunge
      @gmail.mailbox(name) { @gmail.conn.expunge }
    end

    # Cached messages. 
    def messages
      @messages ||= {}
    end
    
    def inspect
      "#<Gmail::Mailbox#{'0x%04x' % (object_id << 1)} name=#{external_name}>"
    end

    def to_s
      name
    end

    MAILBOX_ALIASES.each_key { |mailbox|
      define_method(mailbox) do |*args, &block|
        emails(mailbox, *args, &block)
      end
    }

    def emails_by_seqno(search)
      @gmail.mailbox(name) do
        @gmail.conn.uid_search(search).collect do |uid| 
          message = (messages[uid] ||= Message.new(self, uid))
          message
        end
      end  
    end
    
    # Fetches list of emails which meets given range criteria. 
    #
    # ==== Examples
    #
    #   gmail.inbox.fetch(1..50) # fetches message 1 to 30
    #   gmail.inbox.fetch(30) # fetches last 30 messages
    #
    #   gmail.mailbox("Test") do |box| 
    #     box.fetch(50) do |email|
    #       ... do something with each email...
    #     end
    #   end
    #
    #   start = gmail.inbox.count - 50
    #   gmail.inbox.fetch([start, 1].max..-1) # Fetch last 50 items in inbox
    #
    def fetch(range, &block)
      search = [ 'UID', 'ENVELOPE', 'FLAGS' ]
      @gmail.mailbox(name) do
        list = @gmail.conn.fetch(range, "(#{search.join(' ')})") || []

        list.collect do |msg|
          uid = msg.attr['UID']
          envelope = msg.attr['ENVELOPE']
          flags = msg.attr['FLAGS']       
          # Message.new(self, msg.attr["UID"], message: msg.attr["RFC822"],
                                               # envelope: msg.attr["ENVELOPE"],
                                               # labels: msg.attr["X-GM-LABELS"],
                                               # thread_id: msg.attr["X-GM-THRID"],
                                               # msg_id: msg.attr["X-GM-MSGID"])

          message = (messages[uid] ||= Message.new(self, uid, :envelope => envelope, :flags =>flags))
          block.call(message) if block_given?
          message
        end
      end
    end
  
  end # Message
end # Gmail
