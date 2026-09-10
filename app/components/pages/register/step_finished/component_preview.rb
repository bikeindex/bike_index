# frozen_string_literal: true

module Pages
  module Register
    module StepFinished
      # The completion card, which renders a real bike once there is one
      class ComponentPreview < ApplicationComponentPreview
        # Registered anonymously, so the bike waits on the confirmation email
        def awaiting_email_confirmation
          finished(current_user: nil, owner_email: "someone-else@bikeindex.org")
        end

        # The link is what opens the theft report, so it's what confirming is for here
        def awaiting_email_confirmation_stolen
          finished(current_user: nil, owner_email: "someone-else@bikeindex.org", status: "status_stolen")
        end

        def bike_created
          finished(current_user: lookbook_user, with_bike: true, owner_email: lookbook_user&.email)
        end

        # A theft was the point of the flow, so the card reports it rather than promising
        # to keep watch in case the bike is ever stolen
        def reported_stolen
          finished(current_user: lookbook_user, with_bike: true, owner_email: lookbook_user&.email,
            bike_scope: ::Bike.unscoped.status_stolen)
        end

        # A find is waiting to be claimed rather than looked for, so it says that instead
        # of the checklist a theft ends on
        def reported_found
          finished(current_user: lookbook_user, with_bike: true, owner_email: lookbook_user&.email,
            status: "status_impounded", bike_scope: ::Bike.unscoped.status_impounded)
        end

        # Registered for someone else, so the claim email is what went out
        def registered_for_owner
          finished(current_user: lookbook_user, with_bike: true, owner_email: "someone-else@bikeindex.org")
        end

        # Arrived on the organization's link, so "register another" carries it along
        def scooter_with_organization
          finished(current_user: lookbook_user, with_bike: true, owner_email: lookbook_user&.email,
            cycle_type: "e-scooter", creation_organization_id: lookbook_organization&.id)
        end

        private

        # An ordinary bike unless a preview asks otherwise: a stolen one renders the theft
        # card, which is reported_stolen's to show
        def finished(current_user:, with_bike: false,
          bike_scope: ::Bike.unscoped.where.not(status: :status_stolen), **bike)
          return production_notice("registration") if Rails.env.production?

          created_bike_id = bike_scope.last&.id if with_bike
          return missing_notice("a bike") if with_bike && created_bike_id.blank?

          b_param = ::BParam.new(origin: "register_flow", created_bike_id:,
            params: {bike: bike.compact}.as_json)
          render(Pages::Register::StepFinished::Component.new(b_param:, current_user:))
        end
      end
    end
  end
end
