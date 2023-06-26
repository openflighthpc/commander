require 'slop'

module Commander
  module CLI
    ##
    # Wrapper run command with error handling
    def run!(*args)
      Commander::ErrorHandler.new(program(:name)).start do |handler|
        run(*handler.parse_trace(*args))
      end
    end

    def run(*args)
      instance = Runner.new(
        @program, commands, default_command, groups,
        global_slop, aliases, args
      )
      instance.run
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
    #
    #   # Get data
    #   program :name # => 'Commander'
    #
    # === Keys
    #
    #   :version         (required) Program version triple, ex: '0.0.1'
    #   :description     (required) Program description
    #   :name            Program name, defaults to basename of executable
    #   :config          An optional argument to be passed into the action
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
    # Hash of ungrouped Command objects
    def commands
      @commands ||= {}
    end

    ##
    # Hash of Group objects
    def groups
      @groups ||= {}
    end

    ##
    # Hash of Global Options
    #
    def global_slop
      @global_slop ||= Slop::Options.new.tap do |slop|
        slop.bool '-h', '--help', 'Display help documentation'
        slop.bool '--version', 'Display version information'
      end
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

    def group(name)
      name = name.to_s

      (groups[name] ||= Group.new(name)).tap do |grp|
        yield grp if block_given?
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
  end
end
