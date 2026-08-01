# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module Wrapper
      # One scenario per alert kind. The wrapper resolves these records off current_user, so
      # the previews render the alert components directly off in-memory ones
      class ComponentPreview < ApplicationComponentPreview
        def phone_waiting_confirmation
          render(PhoneWaitingConfirmation::Component.new(user_phone: UserPhone.new(id: 12, phone: "2018884111")))
        end

        def stolen_bike_without_location
          render(StolenBikeWithoutLocation::Component.new(bikes: preview_bikes))
        end

        def theft_alert_without_photo
          render(TheftAlertWithoutPhoto::Component.new(bikes: preview_bikes))
        end

        def unfinished_registration
          render(UnfinishedRegistration::Component.new(b_param: preview_b_param))
        end

        # Every kind ignored, so the wrapper renders nothing
        def no_alert
          render(Component.new(current_user: User.new(alert_slugs: [])))
        end

        private

        # manufacturer_id is what makes it resumable rather than a blank shell
        def preview_b_param
          ::BParam.new(id_token: "preview-token", origin: "register_flow", created_at: Time.current,
            params: {bike: {manufacturer_id: 1, cycle_type: "cargo"}})
        end

        def preview_bikes
          [::Bike.new(id: 12, mnfg_name: "Surly", frame_model: "Cross Check", year: 2018),
            ::Bike.new(id: 13, mnfg_name: "Jamis", frame_model: "Coda", year: 2020, cycle_type: :cargo)]
        end
      end
    end
  end
end
