require 'paint'

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
    # Global options.

    attr_reader :options

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
        @options, @aliases, @args = inputs.map(&:dup)
      @args.reject! { |a| a == '--trace' }
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
    # NOTE: This method does not have error handling, see: run!

    def run
      require_program :version, :description

      parse_global_options
      remove_global_options options, @args

      run_active_command
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
      name = name.to_s
      if block_given?
        @commands[name] = Commander::Command.new(name)
        yield @commands[name]
      end
      @commands[name]
    end

    ##
    # Check if command _name_ is an alias.

    def alias?(name)
      @aliases.include? name.to_s
    end

    ##
    # Check if a command _name_ exists.

    def command_exists?(name)
      @commands[name.to_s]
    end

    #:stopdoc:

    ##
    # Get active command within arguments passed to this runner.

    def active_command
      @__active_command ||= command(command_name_from_args)
    end

    ##
    # Attempts to locate a command name from within the arguments.
    # Supports multi-word commands, using the largest possible match.

    def command_name_from_args
      @__command_name_from_args ||= (valid_command_names_from(*@args.dup).sort.last || @default_command)
    end

    ##
    # Returns array of valid command names found within _args_.

    def valid_command_names_from(*args)
      arg_string = args.delete_if { |value| value =~ /^-/ }.join ' '
      commands.keys.find_all { |name| name if arg_string =~ /^#{name}\b/ }
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
      @args.dup.delete_if do |arg|
        removed << arg if parts.include?(arg) && !removed.include?(arg)
      end
    end

    ##
    # Returns hash of help formatter alias defaults.

    def help_formatter_alias_defaults
      {
        compact: HelpFormatter::TerminalCompact,
      }
    end

    ##
    # Limit commands to those which are subcommands of the one that is active
    def limit_commands_to_subcommands(command)
      commands.select! do |other_sym, _|
        other = other_sym.to_s
        # Do not match sub-sub commands (matches for a second space)
        if /\A#{command.name}\s.*\s/.match?(other)
          false
        # Do match regular sub commands
        elsif /\A#{command.name}\s/.match?(other)
          true
        # Do not match any other commands
        else
          false
        end
      end
    end

    ##
    # Creates default commands such as 'help' which is
    # essentially the same as using the --help switch.
    def run_help_command(args)
      UI.enable_paging if program(:help_paging)
      @help_commands = @commands.dup
      if args.empty? || args[0] == :error
        @help_options = @options
        @help_commands.reject! { |k, v| !!v.hidden }
        old_wrap = $terminal.wrap_at
        $terminal.wrap_at = nil
        program(:nobanner, true) if args[0] == :error
        say help_formatter.render
        $terminal.wrap_at = old_wrap
      else
        command = command args.join(' ')
        require_valid_command command
        if command.sub_command_group?
          limit_commands_to_subcommands(command)
          say help_formatter.render_subcommand(command)
        else
          say help_formatter.render_command(command)
        end
      end
    end

    ##
    # Raises InvalidCommandError when a _command_ is not found.

    def require_valid_command(command = active_command)
      fail InvalidCommandError, 'invalid command', caller if command.nil?
    end

    ##
    # Removes global _options_ from _args_. This prevents an invalid
    # option error from occurring when options are parsed
    # again for the command.

    def remove_global_options(options, args)
      # TODO: refactor with flipflop, please TJ ! have time to refactor me !
      options.each do |option|
        switches = option[:switches].dup
        next if switches.empty?

        if (switch_has_arg = switches.any? { |s| s =~ /[ =]/ })
          switches.map! { |s| s[0, s.index('=') || s.index(' ') || s.length] }
        end

        switches = expand_optionally_negative_switches(switches)

        past_switch, arg_removed = false, false
        args.delete_if do |arg|
          if switches.any? { |s| s == arg }
            arg_removed = !switch_has_arg
            past_switch = true
          elsif past_switch && !arg_removed && arg !~ /^-/
            arg_removed = true
          else
            arg_removed = true
            false
          end
        end
      end
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
    # Parse global command options.

    def parse_global_options
      parser = options.inject(OptionParser.new) do |options, option|
        options.on(*option[:args], &global_option_proc(option[:switches], &option[:proc]))
      end

      options = @args.dup
      begin
        parser.parse!(options)
      rescue OptionParser::InvalidOption => e
        # Remove the offending args and retry.
        options = options.reject { |o| e.args.include?(o) }
        retry
      end
    end

    ##
    # Returns a proc allowing for commands to inherit global options.
    # This functionality works whether a block is present for the global
    # option or not, so simple switches such as --verbose can be used
    # without a block, and used throughout all commands.

    def global_option_proc(switches, &block)
      lambda do |value|
        unless active_command.nil?
          active_command.proxy_options << [Runner.switch_to_sym(switches.last), value]
        end
        if block && !value.nil?
          instance_exec(value, &block)
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

    ##
    # Run the active command.

    def run_active_command
      require_valid_command
      if alias? command_name_from_args
        active_command.run(*(@aliases[command_name_from_args.to_s] + args_without_command_name))
      else
        active_command.run(*args_without_command_name)
      end
    end

    def say(*args) #:nodoc:
      $terminal.say(*args)
    end
  end
end
