# frozen_string_literal: true

module SearchResults
  module MultiResultChip
    class ComponentPreview < ApplicationComponentPreview
      # @!group Results
      def one_result
        render(Component.new(chip_id: "chip_0", result_count: 1, label: "SERIAL111"))
      end

      def many_results
        render(Component.new(chip_id: "chip_1", result_count: 3009, label: "SERIAL222"))
      end

      def no_results
        render(Component.new(chip_id: "chip_2", result_count: 0, label: "NONEXISTENT"))
      end

      def error
        render(Component.new(chip_id: "chip_3", result_count: 0, label: "SERIAL333", error: true, error_message: "Server error 500"))
      end
      # @!endgroup
    end
  end
end
