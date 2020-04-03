module Commander
  module Delegates
    %w(
      command
      program
      run!
      global_option
      alias_command
      default_command
    ).each do |meth|
      eval <<-END, binding, __FILE__, __LINE__
        def #{meth}(*args, &block)
          ::Commander::Runner.instance.#{meth}(*args, &block)
        end
      END
    end

    def defined_commands(*args, &block)
      ::Commander::Runner.instance.commands(*args, &block)
    end
  end
end
