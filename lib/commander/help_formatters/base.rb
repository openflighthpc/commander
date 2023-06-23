module Commander
  ##
  # = Help Formatter
  #
  # Commander's help formatters control the output when
  # either the help command, or --help switch are called.
  # The default formatter is Commander::HelpFormatter::Terminal.

  module HelpFormatter
    class Base
      def initialize(runner)
        @runner = runner
      end

      def render(opts = {})
        'Implement global help here'
      end

      def render_command(command)
        "Implement help for #{command.name} here"
      end

      def render_group(group)
        "Implement help for #{group.name} here"
      end
    end
  end
end
