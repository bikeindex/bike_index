# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module StockPhotos
        # The photo step's Bike Book matches, each pickable as the stock photo standing in for the owner's own
        class Component < ApplicationComponent
          FRAME_ID = "stolen_report_stock_photos"

          # results: Integrations::Bikebook::Catalog.stock_photos
          # selected_url: the stock photo the bike already has
          def initialize(results:, searched:, selected_url: nil)
            @results = results
            @searched = searched
            @selected_url = selected_url
          end

          private

          def years(result) = [result[:first_year], result[:final_year] || translation(".present")].uniq.join("–")
        end
      end
    end
  end
end
