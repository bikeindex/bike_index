# frozen_string_literal: true

module SearchResults::MultiResultChip
  class ComponentPreview < ApplicationComponentPreview
    # @!group Results
    def one_result
      render(Component.new(serial: "SERIAL111", chip_id: "chip_0", result_count: 1))
    end

    def many_results
      render(Component.new(serial: "SERIAL222", chip_id: "chip_1", result_count: 3009))
    end

    def no_results
      render(Component.new(serial: "NONEXISTENT", chip_id: "chip_2", result_count: 0))
    end

    def error
      render(Component.new(serial: "SERIAL333", chip_id: "chip_3", result_count: 0, error: true))
    end
    # @!endgroup
  end
end
