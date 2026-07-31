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

      # Without the bike the registration is only held, waiting on the email
      def heading_text
        translation(@bike.present? ? ".registration_complete" : ".registration_saved")
      end

      def subtitle_text
        return translation(".verify_your_email_html", email: owner_email_tag) if @bike.blank?
        return translation(".we_will_keep_watch", bike_display: @bike.mnfg_name) if self_made?

        translation(".registered_for_owner_html", bike_display: @bike.mnfg_name, email: owner_email_tag)
      end

      def owner_email_tag
        content_tag(:strong, @b_param.owner_email)
      end
    end
  end
end
