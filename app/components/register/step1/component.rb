# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      def initialize(b_param:, current_user: nil)
        @b_param = b_param
        @current_user = current_user
      end

      private

      def cycle_type
        @b_param.type
      end

      def organization
        return @organization if defined?(@organization)

        @organization = @b_param.creation_organization
      end

      # Every rendering of the cycle type is its own span, so register--heading
      # can swap them all when the combobox changes
      def cycle_type_tag
        tag.span(cycle_type, data: {"register--heading-target": "cycleType"})
      end

      def heading_text
        return translation(".register_your_bike_html", cycle_type: cycle_type_tag) if organization.blank?

        translation(".register_your_bike_with_org_html", cycle_type: cycle_type_tag,
          org_name: ERB::Util.html_escape(organization.short_name))
      end

      # slug => the word the heading uses, for register--heading to swap in
      def cycle_type_names
        CycleType.slugs.index_with { |slug| CycleType.new(slug).short_name_translation&.downcase }
      end

      # Only anonymous registrants have anything to wait on, and the email goes
      # out when step 1 is submitted
      def confirmation_email_pending?
        @current_user.blank? && @b_param.partial_email_sent_to.blank?
      end

      # Step 1 is only revisitable once submitted, so this is a return from step 2
      # - where abandoning the registration is worth offering
      def returned_from_step_2?
        @b_param.manufacturer_id.present?
      end
    end
  end
end
