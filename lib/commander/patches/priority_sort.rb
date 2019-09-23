# frozen_string_literal: true

module Commander
  module Patches
    module PrioritySort
      attr_accessor :priority

      def <=>(other)
        # Different classes can not be compared and thus are considered
        # equal in priority
        return 0 unless self.class == other.class

        # Sort firstly based on the commands priority
        comp = (self.priority || 0) <=> (other.priority || 0)

        # Fall back on name comparison if priority is equal
        comp == 0 ? self.name <=> other.name : comp
      end
    end
  end
end
