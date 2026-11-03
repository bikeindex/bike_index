# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module RegistryStats
      class Component < ApplicationComponent
        def initialize(html_class: nil)
          @html_class = html_class
        end

        private

        def items
          total_bikes, recoveries, recoveries_value, organizations =
            Counts.retrieve_many("total_bikes", "recoveries", "recoveries_value", "organizations")

          [
            [abbreviated(total_bikes), translation(".stat_bikes")],
            [number_display(recoveries), translation(".stat_recoveries")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: recoveries_value)),
              translation(".stat_value")],
            [safe_join([number_display(organizations.floor(-2)), "+"]), translation(".stat_partners")]
          ]
        end

        def abbreviated(count)
          return number_display(count) if count < 1_000_000

          "#{number_with_precision(count / 1_000_000.0, precision: 1, round_mode: :floor, strip_insignificant_zeros: true)}M+"
        end
      end
    end
  end
end
