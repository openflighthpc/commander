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
      callable.call if callable
    end
  end

  def self.trace?(args)
    last = args.index('--') || args.length
    args[0..last].include?('--trace')
  end

  def self.error_handler(trace = false)
    yield if block_given?
  rescue StandardError, Interrupt => e
    $stderr.puts e.full_message if trace

    error_msg = e.message
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

