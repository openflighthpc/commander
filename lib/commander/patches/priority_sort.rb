# frozen_string_literal: true

module Commander
  module Patches
    module PrioritySort
      def <=>(other)
        # Different classes can not be compared and thus are considered
        # equal in priority
        return 0 unless self.class == other.class

        # Delegate the sort based on the name
        self.name <=> other.name
      end
    end
  end
end
