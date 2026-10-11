# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module FinishStolenReport
          # Shown to the owner of a bike registered to report stolen, until the stolen report wizard
          # it was handed to has reported it - see BikeServices::Register.report_in_wizard?
          class Component < ApplicationComponent
            def initialize(bike:, owner: false)
              @bike = bike
              @owner = owner
            end

            def render?
              @owner && !@bike.status_stolen? &&
                BParam.where(created_bike_id: @bike.id).where("params ? 'stolen_report_pending'").exists?
            end
          end
        end
      end
    end
  end
end
