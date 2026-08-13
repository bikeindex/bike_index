# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      def initialize(b_param:, steps:, current_user: nil, button_color: nil)
        @b_param = b_param
        @steps = steps
        @current_user = current_user
        @button_color = HexColor.normalize(button_color)
      end

      private

      # Inline, so it beats COLORS - including the hover a one-off color has no palette for
      def button_style
        "background-color: #{@button_color}; border-color: #{@button_color}" if @button_color.present?
      end

      def cycle_type
        @b_param.type
      end

      def organization
        @organization ||= @b_param.creation_organization
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

      # Names this registration rather than leaving it to the session, which another tab
      # may have moved on. Discarding it shouldn't discard everything the link they
      # arrived on carried. The raw status, since BParam#status answers
      # status_with_owner for an unset one
      def start_over_path
        new_register_path({discard_token: @b_param.id_token, organization_id: organization&.slug,
                           status: @b_param.bike["status"], button: @button_color}.compact)
      end

      # slug => the word the heading uses, for register--heading to swap in
      # (the same map bikes/new hands its JS as window.cycleTypeTranslations)
      def cycle_type_names
        CycleType.slug_translation_hash_lowercase_short
      end

      # Step 1 is only revisitable once submitted, so this is a return from step 2
      # - where abandoning the registration is worth offering
      def returned_from_step_2?
        @b_param.manufacturer_id.present?
      end
    end
  end
end
