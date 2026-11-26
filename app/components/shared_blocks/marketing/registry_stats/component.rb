# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module RegistryStats
      class Component < ApplicationComponent
        def initialize(layout: :grid, html_class: nil)
          @layout = layout
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

          "#{Counts.in_millions(count)}M+"
        end
      end
    end
  end
end
