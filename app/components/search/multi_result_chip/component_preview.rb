# frozen_string_literal: true

module Search::MultiResultChip
  class ComponentPreview < ApplicationComponentPreview
    # @!group Results
    def one_result
      render(Component.new(serial: "SERIAL111", serial_chip_id: "chip_0", result_count: 1))
    end

    def many_results
      render(Component.new(serial: "SERIAL222", serial_chip_id: "chip_1", result_count: 3009))
    end

    def no_results
      render(Component.new(serial: "NONEXISTENT", serial_chip_id: "chip_2", result_count: 0))
    end
    # @!endgroup
  end
end
