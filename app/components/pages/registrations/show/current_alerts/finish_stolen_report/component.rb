# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module FinishStolenReport
          # Shown to the owner of a bike registered to report stolen, until the stolen report wizard
          # it was handed to has reported it - see BikeServices::Register.report_in_wizard?
          class Component < ApplicationComponent
            def initialize(bike:, owner: false, margin_classes: "")
              @bike = bike
              @owner = owner
              @margin_classes = margin_classes
            end

            def render?
              @owner && !@bike.status_stolen? &&
                BParam.stolen_report_pending.exists?(created_bike_id: @bike.id)
            end
          end
        end
      end
    end
  end
end
