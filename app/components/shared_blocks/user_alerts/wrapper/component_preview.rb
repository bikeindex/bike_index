# frozen_string_literal: true

module SharedBlocks
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

        private

        # manufacturer_id is what makes it resumable rather than a blank shell, and
        # owner_email matching the creator is what makes it theirs to be alerted about
        def preview_b_param
          creator = ::User.new(email: "preview@bikeindex.org")
          ::BParam.new(id_token: "preview-token", origin: "register_flow", created_at: Time.current,
            creator:, params: {bike: {manufacturer_id: 1, cycle_type: "cargo", owner_email: creator.email}})
        end

        def preview_bikes
          [::Bike.new(id: 12, mnfg_name: "Surly", frame_model: "Cross Check", year: 2018),
            ::Bike.new(id: 13, mnfg_name: "Jamis", frame_model: "Coda", year: 2020, cycle_type: :cargo)]
        end
      end
    end
  end
end
