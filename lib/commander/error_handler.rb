require 'paint'

module Commander
  ##
  # Internal error class to delay rendering help text
  # This is required as the help command points directly to stdout
  # In general this has a bit of a code smell to it, and should
  # not be used publicly
  class InternalCallableError < StandardError
    attr_accessor :callable

    def initialize(msg = nil, &block)
      super(msg)
      self.callable = block
    end

    def call
      callable.call if callable
    end
  end

  ErrorHandler = Struct.new(:program_name, :trace) do
    def parse_trace(*raw_args)
      # Do not modify the original array
      args = raw_args.dup

      # Determines if there is a --trace flag before a --
      trace_index = args.index do |a|
        if a == '--trace'
          self.trace = true
        elsif a == '--'
          break
        else
          false
        end
      end

      # Removes the --trace flag if required
      args.tap { |a| a.delete_at(trace_index) if trace_index }
    end

    def start
      yield(self) if block_given?
    rescue => e
      $stderr.puts e.full_message if trace

      error_msg = "#{Paint[program_name, '#2794d8']}: #{Paint[e.to_s, :red, :bright]}"
      exit_code = e.respond_to?(:exit_code) ?  e.exit_code.to_i : 1
      case e
      when InternalCallableError
        # See: https://shapeshed.com/unix-exit-codes/
        exit_code = 126
        $stderr.puts error_msg
        e.call
      else
        $stderr.puts error_msg
      end
      exit(exit_code)
    end
  end
end

