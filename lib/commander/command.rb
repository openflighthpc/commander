require 'slop'

module Commander
  class Command
    class CommandUsageError < StandardError; end

    attr_accessor :name, :examples, :syntax, :description, :priority
    attr_accessor :summary, :options, :group

    ##
    # Initialize new command with specified _name_.

    def initialize(name, group=nil)
      @name, @examples, @when_called = name.to_s, [], []
      @options = []
      @group = group
    end

    # Allows the commands to be sorted via priority
    def <=>(other)
      # Different classes can not be compared and thus are considered
      # equal in priority
      return 0 unless self.class == other.class

      # Sort firstly based on the commands priority
      comp = (self.priority || 0) <=> (other.priority || 0)

      # Fall back on name comparison if priority is equal
      comp == 0 ? self.name <=> other.name : comp
    end

    def run!(args, opts, config)
      assert_correct_number_of_args!(args)
      callee = @when_called.dup
      callee.shift&.send(callee.shift || :call, args, opts, config)
    end

    ##
    # Add a usage example for this command.
    #
    # Usage examples are later displayed in help documentation
    # created by the help formatters.
    #
    # === Examples
    #
    #   command :something do |c|
    #     c.example "Should do something", "my_command something"
    #   end
    #

    def example(description, command)
      @examples << [description, command]
    end

    ##
    # Add an option.
    #
    # This is the legacy `option` method which now wraps `slop`
    #

    def option(*args, default: nil, &block)
      # Split the description from the switchers
      switches, description = Runner.separate_switches_from_description(*args)

      # Other switches are normally short tags and something like below
      # In this case the VALUE needs to be ignored
      # -k VALUE
      other_switches = switches.dup.tap(&:pop).map do |string|
        string.split(' ').first
      end

      long_switch, meta = switches.last.split(' ', 2)

      # The meta flag is the VALUE from denotes if its a boolean or
      # string method
      method = meta.nil? ? :bool : :string

      # Adds the option to Slop
      slop.send(method, *other_switches, long_switch, description, default: default)
    end

    def slop
      @slop ||= Slop::Options.new
    end

    ##
    # Handle execution of command. The handler may be a class,
    # object, or block (see examples below).
    #
    # === Examples
    #
    #   # Simple block handling
    #   c.when_called do |args, options, config|
    #      # do something
    #   end
    #
    #   # Pass an object to handle callback (requires method symbol)
    #   c.when_called SomeObject, :some_method
    #

    def when_called(*args, &block)
      fail ArgumentError, 'must pass an object, class, or block.' if args.empty? && !block
      @when_called = block ? [block] : args
    end
    alias action when_called

    ##
    # Flags the command not to appear in general help text
    #

    def hidden(set = true)
      @hidden ||= set
    end

    def inspect
      "<Commander::Command:#{name}>"
    end

    def assert_correct_number_of_args!(args)
      return if primary_command_word == 'help'
      too_many = too_many_args?(args)
      if too_many
        raise CommandUsageError, "excess arguments for command '#{primary_command_word}'"
      elsif too_few_args?(args)
        raise CommandUsageError, "insufficient arguments for command '#{primary_command_word}'"
      end
    end

    def syntax_parts
      @syntax_parts ||= syntax.split.tap do |parts|
        while part = parts.shift do
          break if part == primary_command_word || parts.length == 0
        end
      end
    end

    def primary_command_word
      name.split.last
    end

    def total_argument_count
      syntax_parts.length
    end

    def optional_argument_count
      syntax_parts.select do |part|
        part[0] == '[' && part[-1] == ']'
      end.length
    end

    def variable_arg?
      syntax_parts.any? {|part| part[-4..-1] == '...]' || part[-3..-1] == '...'}
    end

    def required_argument_count
      total_argument_count - optional_argument_count
    end

    def too_many_args?(args)
      !variable_arg? && args.length > total_argument_count
    end

    def too_few_args?(args)
      args.length < required_argument_count
    end
  end
end
