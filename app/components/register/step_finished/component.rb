# frozen_string_literal: true

module Register
  module StepFinished
    # The completion card: bike created, or awaiting email verification
    class Component < ApplicationComponent
      def initialize(b_param:, current_user: nil)
        @b_param = b_param
        @current_user = current_user
        @bike = b_param.created_bike
      end

      private

      def cycle_type
        @b_param.type
      end

      # Signed in as the owner - to anyone else the registration belongs to the
      # address it was made for, which is where the claim email went
      def self_made?
        @b_param.self_made?(@current_user)
      end

      # The bike's own status, once there's a bike to have one
      def stolen? = @bike&.status_stolen?

      # Without the bike the registration is only held, waiting on the email
      def heading_text
        return translation(".registration_saved") if @bike.blank?

        translation(stolen? ? ".reported_stolen" : ".registration_complete")
      end

      # A theft isn't a bike being watched over, it's one already being looked for
      def subtitle_text
        return translation(".verify_your_email_html", email: owner_email_tag) if @bike.blank?
        return translation(".registered_for_owner_html", bike_display: @bike.mnfg_name, email: owner_email_tag) unless self_made?

        translation(stolen? ? ".listed_as_stolen" : ".we_will_keep_watch", bike_display: @bike.mnfg_name)
      end

      def owner_email_tag
        content_tag(:strong, @b_param.owner_email)
      end

      # Only a found registration has an impound record to fill in
      def found?
        %w[status_abandoned status_impounded unregistered_parking_notification].include?(@b_param.status)
      end

      # Registering again stays with the organization they arrived through, rather
      # than dropping them onto an unattributed registration
      def register_another_path
        new_register_path({organization_id: @b_param.creation_organization&.slug}.compact)
      end
    end
  end
end
