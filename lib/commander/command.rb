require 'optparse'
require 'commander/patches/implicit-short-tags'

OptionParser.prepend Commander::Patches::ImplicitShortTags

module Commander
  class Command
    class CommandUsageError < StandardError; end

    attr_accessor :name, :examples, :syntax, :description, :priority
    attr_accessor :summary, :proxy_options, :options

    ##
    # Options struct.

    class Options
      include Blank

      def initialize
        @table = {}
      end

      def __hash__
        @table
      end

      def method_missing(meth, *args)
        meth.to_s =~ /=$/ ? @table[meth.to_s.chop.to_sym] = args.first : @table[meth]
      end

      def default(defaults = {})
        @table = defaults.merge! @table
      end

      def inspect
        "<Commander::Command::Options #{ __hash__.map { |k, v| "#{k}=#{v.inspect}" }.join(', ') }>"
      end
    end

    ##
    # Initialize new command with specified _name_.

    def initialize(name)
      @name, @examples, @when_called = name.to_s, [], []
      @options, @proxy_options = [], []
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
    # Options are parsed via OptionParser so view it
    # for additional usage documentation. A block may optionally be
    # passed to handle the option, otherwise the _options_ struct seen below
    # contains the results of this option. This handles common formats such as:
    #
    #   -h, --help          options.help           # => bool
    #   --[no-]feature      options.feature        # => bool
    #   --large-switch      options.large_switch   # => bool
    #   --file FILE         options.file           # => file passed
    #   --list WORDS        options.list           # => array
    #   --date [DATE]       options.date           # => date or nil when optional argument not set
    #
    # === Examples
    #
    #   command :something do |c|
    #     c.option '--recursive', 'Do something recursively'
    #     c.option '--file FILE', 'Specify a file'
    #     c.option('--info', 'Display info') { puts "handle with block" }
    #     c.option '--[no-]feature', 'With or without feature'
    #     c.option '--list FILES', Array, 'List the files specified'
    #
    #     c.when_called do |args, options|
    #       do_something_recursively if options.recursive
    #       do_something_with_file options.file if options.file
    #     end
    #   end
    #
    # === Help Formatters
    #
    # This method also parses the arguments passed in order to determine
    # which were switches, and which were descriptions for the
    # option which can later be used within help formatters
    # using option[:switches] and option[:description].
    #
    # === Input Parsing
    #
    # Since Commander utilizes OptionParser you can pre-parse and evaluate
    # option arguments. Simply require 'optparse/time', or 'optparse/date', as these
    # objects must respond to #parse.
    #
    #   c.option '--time TIME', Time
    #   c.option '--date [DATE]', Date
    #

    def option(*args, default: nil, &block)
      switches, description = Runner.separate_switches_from_description(*args)
      proc = block || option_proc(switches)
      @options << {
        args: args,
        proc: proc,
        switches: switches,
        description: description
      }.tap { |o| o[:default] = default unless default.nil? }
    end

    ##
    # Handle execution of command. The handler may be a class,
    # object, or block (see examples below).
    #
    # === Examples
    #
    #   # Simple block handling
    #   c.when_called do |args, options|
    #      # do something
    #   end
    #
    #   # Create inst of Something and pass args / options
    #   c.when_called MyLib::Command::Something
    #
    #   # Create inst of Something and use arbitrary method
    #    c.when_called MyLib::Command::Something, :some_method
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
    # Run the command with _args_.
    #
    # * parses options, call option blocks
    # * invokes when_called proc
    #

    def run(*args)
      call parse_options_and_call_procs(*args)
    end

    #:stopdoc:

    ##
    # Parses options and calls associated procs,
    # returning the arguments remaining.

    def parse_options_and_call_procs(*args)
      opt = @options.each_with_object(OptionParser.new) do |option, opts|
        opts.on(*option[:args], &option[:proc])
        opts
      end
      default_opt = @options.each_with_object([]) do |h, arr|
        if h.key?(:default)
          arr.push(h[:switches][0].split[0])
          arr.push(h[:default].to_s)
        end
      end
      opt.parse! default_opt
      opt.parse! args
    end

    ##
    # Call the commands when_called block with _args_.

    def call(args = [])
      # Verifies there is enough args
      unless syntax_parts[0..1] == ['commander', 'help']
        assert_correct_number_of_args!(args)
      end

      callee = @when_called.dup
      object = callee.shift
      meth = callee.shift || :call
      options = proxy_option_struct
      case object
      when Proc then object.call(args, options)
      when Class then meth != :call ? object.new.send(meth, args, options) : object.new(args, options)
      else object.send(meth, args, options) if object
      end
    end

    ##
    # Creates an Options instance populated with the option values
    # collected by the #option_proc.

    def proxy_option_struct
      proxy_options.each_with_object(Options.new) do |(option, value), options|
        # options that are present will evaluate to true
        value = true if value.nil?
        options.__send__ :"#{option}=", value
        options
      end
    end

    ##
    # Option proxy proc used when a block is not explicitly passed
    # via the #option method. This allows commander to auto-populate
    # and work with option values.

    def option_proc(switches)
      ->(value) { proxy_options << [Runner.switch_to_sym(switches.last), value] }
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
