# frozen_string_literal: true

module Register
  module StepFinished
    # The completion card, which renders a real bike once there is one
    class ComponentPreview < ApplicationComponentPreview
      # Registered anonymously, so the bike waits on the confirmation email
      def awaiting_email_confirmation
        finished(owner_email: "someone-else@bikeindex.org", current_user: nil)
      end

      def bike_created
        finished(owner_email: lookbook_user&.email, current_user: lookbook_user, with_bike: true)
      end

      # Registered for someone else, so the claim email is what went out
      def registered_for_owner
        finished(owner_email: "someone-else@bikeindex.org", current_user: lookbook_user, with_bike: true)
      end

      private

      def finished(owner_email:, current_user:, with_bike: false)
        return production_notice("registration") if Rails.env.production?

        created_bike_id = ::Bike.unscoped.last&.id if with_bike
        return missing_notice("a bike") if with_bike && created_bike_id.blank?

        b_param = ::BParam.new(origin: "register_flow", created_bike_id:,
          params: {bike: {owner_email:}}.as_json)
        render(Register::StepFinished::Component.new(b_param:, current_user:))
      end
    end
  end
end
