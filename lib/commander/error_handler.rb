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

  def self.traceable_error_handler(*args)
    # Determines if there is a --trace flag before a --
    trace_index = args.index do |a|
      if a == '--trace'
        true
      elsif a == '--'
        break
      else
        false
      end
    end

    # Removes the --trace flag if required
    new_args = args.dup
    new_args.delete_at(trace_index) if trace_index

    # Start the actual error handler
    error_handler(!!trace_index) do
      yield(new_args) if block_given?
    end
  end

  def self.error_handler(trace = false)
    yield if block_given?
  rescue StandardError => e
    $stderr.puts e.full_message if trace

    error_msg = e.message
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

