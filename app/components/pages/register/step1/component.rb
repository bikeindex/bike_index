# frozen_string_literal: true

module Pages
  module Register
    module Step1
      # Step 1 of the registration flow: the quick-start form
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, current_user: nil, embed: false, button_color: nil,
          button_hover_color: nil, skip_heading: false)
          @b_param = b_param
          @steps = steps
          @current_user = current_user
          @embed = embed
          @button_color = button_color
          @button_hover_color = button_hover_color
          @skip_heading = skip_heading
        end

        private

        # What a frame can't have: a Turbo submission, which Turbo would render back inside it
        # (the target is ignored unless it names an iframe); autofocus, which scrolls the
        # embedding page down to the frame on load; and form-persist, whose localStorage is
        # partitioned per embedding site and blocked outright in Safari
        def form_options
          return {data: {turbo: false}, html: {target: "_top"}} if @embed

          {data: {turbo: true, controller: "autofocus form-persist register--retry",
                  form_persist_key_value: "register-start-#{@b_param.id_token}",
                  action: "input->form-persist#save hw-combobox:selection->form-persist#save " \
                    "submit->form-persist#clear"}}
        end

        # Derived when the frame's src doesn't name one
        def button_hover_color
          @button_hover_color.presence || HexColor.darken_hex(@button_color)
        end

        # The shade rides a variable because Tailwind only generates classes it can read
        # literally, and is !important because the inline color outranks a class
        def button_options
          return {html_class: "tw:w-full"} unless @button_color

          {html_class: "tw:w-full tw:not-disabled:not-aria-disabled:hover:bg-[var(--button-hover-color)]! " \
            "tw:not-disabled:not-aria-disabled:hover:border-[var(--button-hover-color)]!",
           style: "background-color: #{@button_color}; border-color: #{@button_color}; " \
             "--button-hover-color: #{button_hover_color}"}
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

        # owner_email is the setting bikes/new labels its email field with
        def email_label
          OrgServices::Displayer.registration_field_label(organization, "owner_email", strip_tags: true) ||
            (translation(".email_school", org_name: organization.short_name) if organization&.school?) ||
            translation(".email")
        end

        def email_placeholder
          OrgServices::Displayer.registration_field_label(organization, "email_placeholder", strip_tags: true) ||
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
end
