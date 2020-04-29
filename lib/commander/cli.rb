module Commander
  ##
  # Internal error class to delay rendering help text
  # This is required as the help command pints directly to stdout
  # In general this has a bit of a code smell to it, and should
  # not be used publicly
  class InternalCallableError < StandardError
    attr_accessor :callable

    def initialize(msg = nil, &block)
      super(msg)
      self.callable = block
    end

    def call
      callable.call
    end
  end

  module CLI
    ##
    # Wrapper run command with error handling
    def run!(*args)
      instance = Runner.new(
        @program, commands, default_command,
        global_options, aliases, args
      )
      instance.run
    rescue StandardError, Interrupt => e
      $stderr.puts e.backtrace.reverse if args.include?('--trace')
      error_handler(instance, e)
    end

    ##
    # Assign program information.
    #
    # === Examples
    #
    #   # Set data
    #   program :name, 'Commander'
    #   program :version, Commander::VERSION
    #   program :description, 'Commander utility program.'
    #   program :help, 'Copyright', '2008 TJ Holowaychuk'
    #   program :help, 'Anything', 'You want'
    #   program :help_formatter, :compact
    #   program :help_formatter, Commander::HelpFormatter::TerminalCompact
    #
    #   # Get data
    #   program :name # => 'Commander'
    #
    # === Keys
    #
    #   :version         (required) Program version triple, ex: '0.0.1'
    #   :description     (required) Program description
    #   :name            Program name, defaults to basename of executable
    #   :help_formatter  Defaults to Commander::HelpFormatter::Terminal
    #   :help            Allows addition of arbitrary global help blocks
    #   :help_paging     Flag for toggling help paging
    #

    def program(key, *args, &block)
      @program ||= {
        help_formatter: HelpFormatter::Terminal,
        name: File.basename($PROGRAM_NAME),
        help_paging: true,
      }

      if key == :help && !args.empty?
        @program[:help] ||= {}
        @program[:help][args.first] = args.at(1)
      elsif key == :help_formatter && !args.empty?
        @program[key] = (@help_formatter_aliases[args.first] || args.first)
      elsif block
        @program[key] = block
      else
        unless args.empty?
          @program[key] = args.count == 1 ? args[0] : args
        end
        @program[key]
      end
    end

    ##
    # Default command _name_ to be used when no other
    # command is found in the arguments.

    def default_command(name = nil)
      @default_command = name unless name.nil?
      @default_command
    end


    ##
    # Hash of Command objects
    def commands
      @commands ||= {}
    end

    ##
    # Hash of Global Options
    def global_options
      @global_options ||= begin
        @global_options = [] # Allows Recursive - Refactor
        global_option('-h', '--help', 'Display help documentation') do
          args = @args - %w(-h --help)
          command(:help).run(*args)
          exit 0
        end
        global_option('--version', 'Display version information') do
          say version
          exit 0
        end
      end
    end

    ##
    # Add a global option; follows the same syntax as Command#option
    # This would be used for switches such as --version
    # NOTE: --trace is special and does not appear in the help
    # It is intended for debugging purposes

    def global_option(*args, &block)
      switches, description = Runner.separate_switches_from_description(*args)
      global_options << {
        args: args,
        proc: block,
        switches: switches,
        description: description,
      }
    end

    ##
    # Define and get a command by name
    #
    def command(name)
      name = name.to_s
      (commands[name] ||= Command.new(name)).tap do |cmd|
        yield cmd if block_given?
      end
    end

    # A hash of known aliases
    def aliases
      @aliases ||= {}
    end

    ##
    # Alias command _name_ with _alias_name_. Optionally _args_ may be passed
    # as if they were being passed straight to the original command via the command-line.

    def alias_command(alias_name, name, *args)
      commands[alias_name.to_s] = command name
      aliases[alias_name.to_s] = args
    end

    def error_handler(_, e)
      error_msg = "#{Paint[@program[:name], '#2794d8']}: #{Paint[e.to_s, :red, :bright]}"
      exit_code = e.respond_to?(:exit_code) ?  e.exit_code.to_i : 1
      case e
      when InternalCallableError
        # See: https://shapeshed.com/unix-exit-codes/
        exit_code = 126
        $stderr.puts error_msg
        e.call
      when Interrupt
        $stderr.puts 'Received Interrupt!'
        # See: https://shapeshed.com/unix-exit-codes/
        exit_code = 130
      else
        $stderr.puts error_msg
      end
      exit(exit_code)
    end
  end
end
