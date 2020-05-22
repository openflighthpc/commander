require 'paint'
require 'ostruct'

module Commander
  class Runner
    #--
    # Exceptions
    #++
    class CommandError < StandardError; end
    class InvalidCommandError < CommandError; end

    ##
    # Array of commands.

    attr_reader :commands

    ##
    # The global Slop Options
    attr_reader :global_slop

    ##
    # Hash of help formatter aliases.

    attr_reader :help_formatter_aliases

    ##
    # Initialize a new command runner. Optionally
    # supplying _args_ for mocking, or arbitrary usage.

    ##
    # Display the backtrace in the event of an error
    attr_accessor :trace

    def initialize(*inputs)
      @program, @commands, @default_command, \
        @global_slop, @aliases, @args = inputs.map(&:dup)

      @commands['help'] ||= Command.new('help').tap do |c|
        c.syntax = "#{program(:name)} help [command]"
        c.description = 'Display global or [command] help documentation'
        c.example 'Display global help', "#{program(:name)} help"
        c.example "Display help for 'foo'", "#{program(:name)} help foo"
        c.when_called do |help_args, _|
          self.run_help_command(help_args)
        end
      end
      @help_formatter_aliases = help_formatter_alias_defaults
    end

    ##
    # Run command parsing and execution process
    INBUILT_ERRORS = [
      OptionParser::InvalidOption,
      Command::CommandUsageError,
      InvalidCommandError
    ]

    def run
      require_program :version, :description

      # Determine where the arguments/ options start
      remaining_args = if alias? command_name_from_args
        @aliases[command_name_from_args.to_s] + args_without_command_name
      else
        args_without_command_name
      end

      # Combines the global and command options into a single parser
      global_opts = global_slop.options
      command_opts = active_command? ? active_command.slop.options : []
      opts = [*global_opts, *command_opts]
      parser = Slop::Parser.new(opts)

      # Parsers the arguments/opts and fetches the config
      parser.parse(remaining_args)
      opts = OpenStruct.new parser.parse(remaining_args).to_h
      remaining_args = parser.arguments
      config = program(:config).dup

      if opts.version
        # Return the version
        say version
        exit 0
      elsif opts.help && active_command?
        # Return help for the active_command
        run_help_command([active_command!.name])
      elsif active_command?
        # Run the active_command
        active_command.run!(remaining_args, opts, config)
      else
        # Return generic help
        run_help_command('')
      end
    rescue => e
      msg = "#{Paint[program(:name), '#2794d8']}: #{Paint[e.to_s, :red, :bright]}"
      new_error = e.exception(msg)

      if INBUILT_ERRORS.include?(new_error.class)
        new_error = InternalCallableError.new(e.message) do
          $stderr.puts "\nUsage:\n\n"
          name = active_command? ? active_command.name : :error
          run_help_command([name])
        end
      end
      raise new_error
    end

    ##
    # Return program version.

    def version
      format('%s %s', program(:name), program(:version))
    end

    ##
    # The hash of program variables
    #
    def program(key, default = nil)
      @program[key] ||= default if default
      @program[key]
    end

    ##
    # Creates and yields a command instance when a block is passed.
    # Otherwise attempts to return the command, raising InvalidCommandError when
    # it does not exist.
    #
    # === Examples
    #
    #   command :my_command do |c|
    #     c.when_called do |args|
    #       # Code
    #     end
    #   end
    #

    def command(name)
      @commands[name.to_s]
    end

    ##
    # Check if command _name_ is an alias.

    def alias?(name)
      @aliases.include? name.to_s
    end

    #:stopdoc:

    ##
    # Get active command within arguments passed to this runner.
    # It will try an run the default if arguments have been provided
    # It can not run a default command that is flags-only
    # This is to provide consistent behaviour to --help
    #

    def active_command
      @__active_command ||= begin
        if named_command = command(command_name_from_args)
          named_command
        elsif default_command? && flagless_args_string.length > 0
          default_command
        end
      end
    end

    def active_command!
      active_command.tap { |c| require_valid_command(c) }
    end

    def active_command?
      active_command ? true : false
    end

    def default_command
      @__default_command ||= command(@default_command)
    end

    def default_command?
      default_command ? true : false
    end

    ##
    # Attempts to locate a command name from within the arguments.
    # Supports multi-word commands, using the largest possible match.

    def command_name_from_args
      @__command_name_from_args ||= valid_command_names_from(*@args.dup).sort.last
    end

    def flagless_args_string
      @flagless_args_string ||= @args.reject { |value| value =~ /^-/ }.join ' '
    end

    ##
    # Returns array of valid command names found within _args_.

    def valid_command_names_from(*args)
      commands.keys.find_all do |name|
        name if flagless_args_string =~ /^#{name}(?![[:graph:]])/
      end
    end

    ##
    # Help formatter instance.

    def help_formatter
      @__help_formatter ||= program(:help_formatter).new self
    end

    ##
    # Return arguments without the command name.

    def args_without_command_name
      removed = []
      parts = command_name_from_args.split rescue []
      @args.reject do |arg|
        removed << arg if parts.include?(arg) && !removed.include?(arg)
      end
    end

    ##
    # Returns hash of help formatter alias defaults.

    def help_formatter_alias_defaults
      {
      }
    end

    ##
    # Creates default commands such as 'help' which is
    # essentially the same as using the --help switch.
    def run_help_command(args)
      UI.enable_paging if program(:help_paging)
      @help_commands = @commands.reject { |_, v| v.hidden(false) }.to_h
      if args.empty? || args[0] == :error
        @help_options = []
        old_wrap = $terminal.wrap_at
        $terminal.wrap_at = nil
        program(:nobanner, true) if args[0] == :error
        say help_formatter.render
        $terminal.wrap_at = old_wrap
      else
        command = command args.join(' ')
        require_valid_command command
        say help_formatter.render_command(command)
      end
    end

    ##
    # Raises InvalidCommandError when a _command_ is not found.

    def require_valid_command(command)
      fail InvalidCommandError, 'invalid command', caller if command.nil?
    end

    # expand switches of the style '--[no-]blah' into both their
    # '--blah' and '--no-blah' variants, so that they can be
    # properly detected and removed
    def expand_optionally_negative_switches(switches)
      switches.reduce([]) do |memo, val|
        if val =~ /\[no-\]/
          memo << val.gsub(/\[no-\]/, '')
          memo << val.gsub(/\[no-\]/, 'no-')
        else
          memo << val
        end
      end
    end

    ##
    # Raises a CommandError when the program any of the _keys_ are not present, or empty.

    def require_program(*keys)
      keys.each do |key|
        fail CommandError, "program #{key} required" if program(key).nil? || program(key).empty?
      end
    end

    ##
    # Return switches and description separated from the _args_ passed.

    def self.separate_switches_from_description(*args)
      switches = args.find_all { |arg| arg.to_s =~ /^-/ }
      description = args.last if args.last.is_a?(String) && !args.last.match(/^-/)
      [switches, description]
    end

    ##
    # Attempts to generate a method name symbol from +switch+.
    # For example:
    #
    #   -h                 # => :h
    #   --trace            # => :trace
    #   --some-switch      # => :some_switch
    #   --[no-]feature     # => :feature
    #   --file FILE        # => :file
    #   --list of,things   # => :list
    #

    def self.switch_to_sym(switch)
      switch.scan(/[\-\]](\w+)/).join('_').to_sym rescue nil
    end

    def say(*args) #:nodoc:
      $terminal.say(*args)
    end
  end
end
