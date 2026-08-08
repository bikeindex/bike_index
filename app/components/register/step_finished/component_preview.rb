# frozen_string_literal: true

module Register
  module StepFinished
    # The completion card, which renders a real bike once there is one
    class ComponentPreview < ApplicationComponentPreview
      # Registered anonymously, so the bike waits on the confirmation email
      def awaiting_email_confirmation
        finished(current_user: nil, owner_email: "someone-else@bikeindex.org")
      end

      def bike_created
        finished(current_user: lookbook_user, with_bike: true, owner_email: lookbook_user&.email)
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

      def finished(current_user:, with_bike: false, **bike)
        return production_notice("registration") if Rails.env.production?

        created_bike_id = ::Bike.unscoped.last&.id if with_bike
        return missing_notice("a bike") if with_bike && created_bike_id.blank?

        b_param = ::BParam.new(origin: "register_flow", created_bike_id:,
          params: {bike: bike.compact}.as_json)
        render(Register::StepFinished::Component.new(b_param:, current_user:))
      end
    end
  end
end
