# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      def initialize(b_param:, steps:, current_user: nil, embed: false, button_color: nil)
        @b_param = b_param
        @steps = steps
        @current_user = current_user
        @embed = embed
        # Sanitized here, since this is where it reaches a style attribute
        @button_color = HexColor.normalize(button_color)
      end

      private

      # Turbo ignores a form's target unless it names an iframe, so a Turbo submission would
      # render step 2 back inside the frame. Nor does autofocus belong in one - it scrolls
      # the embedding page down to the frame on load
      def form_options
        return {data: {turbo: false}, html: {target: "_top"}} if @embed

        {data: {turbo: true, controller: "autofocus register--retry"}}
      end

      # The hover shade rides a variable because Tailwind only generates classes it can
      # read literally, and is !important because the inline color outranks a class
      def button_style
        return unless @button_color

        "background-color: #{@button_color}; border-color: #{@button_color}; " \
          "--button-hover-color: #{HexColor.darken(@button_color)}"
      end

      def button_class
        return "tw:w-full" if @button_color.blank?

        "tw:w-full tw:hover:bg-[var(--button-hover-color)]! tw:hover:border-[var(--button-hover-color)]!"
      end

      def cycle_type
        @b_param.type
      end

      def organization
        @organization ||= @b_param.creation_organization
      end

      # Its own span, so register--heading can swap the word when the combobox changes
      def cycle_type_tag
        tag.span(cycle_type, data: {"register--heading-target": "cycleType"})
      end

      # A university wants the campus address, not any address the rider has. The label a
      # paid organization sets in admin wins; failing that a school's name stands in for
      # the example, which is what the legacy embed form does with the same setting
      def email_placeholder
        helpers.registration_field_label(organization, "owner_email", strip_tags: true) ||
          (translation(".email_placeholder_school", org_name: organization.short_name) if organization&.school?) ||
          translation(".email_placeholder")
      end

      # The step is still asking what's being registered, so the heading can't name the
      # type. Framed, the page around it already says whose registration this is
      def heading_text
        return translation(".register_your_vehicle") if @embed || organization.blank?

        translation(".register_your_vehicle_with_org", org_name: organization.short_name)
      end

      # Names this registration rather than leaving it to the session, which another tab
      # may have moved on. Discarding it shouldn't discard how they arrived - the
      # organization it's attributed to, or the status they came to report. The raw
      # status, since BParam#status answers status_with_owner for an unset one
      def start_over_path
        new_register_path({discard_token: @b_param.id_token, organization_id: organization&.slug,
                           status: @b_param.bike["status"]}.compact)
      end

      # slug => the word the section label uses, for register--heading to swap in
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
