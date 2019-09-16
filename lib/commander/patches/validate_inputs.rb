# frozen_string_literal: true

module Commander
  module Patches
    # An error in the usage of a command; will happen in practise and error
    # message should be shown along with command usage info.
    class CommandUsageError < StandardError; end

    module ValidateInputs
      # This is used to switch the Patch off during the original test of
      # Commander. It is VERY MUCH a hack but it works
      PatchEnabled = true

      def call(args = [])
        return super unless PatchEnabled
        return super if syntax_parts[0..1] == ['commander', 'help']

        # Use defined syntax to validate how many args this command can be
        # passed.
        assert_correct_number_of_args!(args)

        # Invoke original method.
        super(args)
      end

      private

      def assert_correct_number_of_args!(args)
        return if primary_command_word == 'help'
        too_many = too_many_args?(args)
        if too_many && sub_command_group?
          raise CommandUsageError, "unrecognised command. Please select from the following:"
        elsif too_many
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
end
