# frozen_string_literal: true

module Pages
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

        # The bike's own status once it exists, otherwise what the registration is for -
        # the confirmation page asks before there's a bike
        def stolen? = @bike.present? ? @bike.status_stolen? : @b_param.status_stolen?

        # display_checklist? is address_present? - a theft reported through this flow always
        # has one, but a bike created some other way and shown here might not
        def stolen_checklist?
          @bike.present? && stolen? && @bike.current_stolen_record&.display_checklist?
        end

        # Their own theft, rather than one reported for whoever the registration is for
        def own_theft? = stolen? && self_made?

        # Without the bike the registration is only held, waiting on the email
        def heading_text
          return translation(".progress_saved") if @bike.blank?
          return translation(".listed_as_stolen", bike_display: @bike.mnfg_name) if own_theft?
          return translation(".reported_stolen") if stolen?
          return translation(".listed_as_found", bike_display: @bike.mnfg_name) if found?

          translation(".registration_complete")
        end

        # Nothing under their own theft's heading - it already says what happened, and the
        # checklist below is what there is to read next
        def subtitle_text
          return translation(".verify_your_email_html", email: owner_email_tag) if @bike.blank?
          return if own_theft?
          # A find isn't theirs to be watched over, and isn't claimed by the address it was
          # registered for - it's claimed by whoever lost it
          return translation(".owner_can_claim") if found?
          return translation(".registered_for_owner_html", bike_display: @bike.mnfg_name, email: owner_email_tag) unless self_made?

          translation(".we_will_keep_watch", bike_display: @bike.mnfg_name)
        end

        def owner_email_tag
          content_tag(:strong, @b_param.owner_email)
        end

        # The bike's own status once it exists, otherwise what the registration is for -
        # only a find has an impound record to fill in
        def found?
          return @bike.status_impounded? if @bike.present?

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
end
