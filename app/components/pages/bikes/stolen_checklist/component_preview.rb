# frozen_string_literal: true

module Pages
  module Bikes
    module StolenChecklist
      # Renders against a real stolen record, since what's ticked off is read from it
      class ComponentPreview < ApplicationComponentPreview
        def default
          checklist { true }
        end

        # The Netherlands is the only country we have reporting instructions for
        def netherlands
          checklist { it.country == ::Country.netherlands }
        end

        private

        def checklist(&matching)
          return production_notice("bikes") if Rails.env.production?

          stolen_record = ::StolenRecord.where(current: true).order(id: :desc)
            .detect { it.display_checklist? && matching.call(it) }
          return missing_notice("a stolen record with a location") if stolen_record.blank?

          render(Pages::Bikes::StolenChecklist::Component.new(bike: stolen_record.bike, stolen_record:))
        end
      end
    end
  end
end
