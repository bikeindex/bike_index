# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ChartCard
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Org::Search::ChartCard::Component.new(scope: "year", scope_paths:,
              chart:, stats:))
          end

          def search_scope
            render(Pages::Org::Search::ChartCard::Component.new(scope: "search", scope_paths:,
              chart:, stats:))
          end

          # What the card shows until the lazy frame answers
          # @display javascript_off true
          def loading
            render(Pages::Org::Search::ChartCard::Component.new(src: scope_paths[:year], scope_paths:))
          end

          private

          def scope_paths
            {search: "?chart_scope=search", year: "?chart_scope=year"}
          end

          def stats
            [ComponentStructs::RegistrationStat.new(key: :registrations, count: 4182, previous_count: 3858),
              ComponentStructs::RegistrationStat.new(key: :motorized, count: 911, previous_count: 753),
              ComponentStructs::RegistrationStat.new(key: :stolen, count: 46, previous_count: 43)]
          end

          def chart
            months = 12.downto(1).map { (Time.current.beginning_of_month - it.months).to_date }
            UI::Chart::Component.new(stacked: true, height: "180px", colors: %w[#2563eb #a855f7 #dc2626],
              series: [{name: "Registrations", data: months.map { [it, rand(300..500)] }.to_h},
                {name: "E-bike", data: months.map { [it, rand(40..120)] }.to_h},
                {name: "Stolen", data: months.map { [it, rand(5..30)] }.to_h}])
          end
        end
      end
    end
  end
end
