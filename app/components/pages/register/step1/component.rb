# frozen_string_literal: true

module Pages
  module Register
    module Step1
      # Step 1 of the registration flow: the quick-start form
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, current_user: nil, embed: false, button_color: nil,
          button_hover_color: nil, skip_heading: false, organization: nil)
          @b_param = b_param
          @steps = steps
          @current_user = current_user
          @embed = embed
          @button_color = button_color
          @button_hover_color = button_hover_color
          @skip_heading = skip_heading
          @organization = organization
        end

        private

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

        def organization
          @organization ||= @b_param.creation_organization
        end

        # Names this registration rather than leaving it to the session, which another tab
        # may have moved on. Discarding it shouldn't discard how they arrived - the
        # organization it's attributed to, or the status they came to report. The raw
        # status, since BParam#status answers status_with_owner for an unset one
        def start_over_path
          new_register_path({discard_token: @b_param.id_token, organization_id: organization&.slug,
                             status: @b_param.bike["status"]}.compact)
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
