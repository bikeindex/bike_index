# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module StockPhotos
        # The photo step's Bike Book matches, each pickable as the stock photo standing in for the owner's own
        class Component < ApplicationComponent
          FRAME_ID = "stolen_report_stock_photos"

          # results: Integrations::Bikebook::Catalog.stock_photos
          # selected_url: the stock photo the bike already has, or the one picked before this search
          # selected_id: that pick's Bike Book model, kept chosen when this search doesn't find it
          def initialize(results:, searched:, selected_url: nil, selected_id: nil)
            @results = results
            @searched = searched
            @selected_url = selected_url
            @selected_id = selected_id if selected_id.to_s.match?(Integrations::Bikebook::Catalog::MODEL_ID)
          end

          private

          def keep_selection? = @selected_id.present? && @results.none? { it[:id] == @selected_id }

          def years(result) = [result[:first_year], result[:final_year] || translation(".present")].uniq.join("–")
        end
      end
    end
  end
end
