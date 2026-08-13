# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      # embed: framed on an organization's landing page (RegisterController#embed)
      def initialize(b_param:, steps:, current_user: nil, embed: false)
        @b_param = b_param
        @steps = steps
        @current_user = current_user
        @embed = embed
      end

      private

      # Turbo ignores a form's target unless it names an iframe, so a Turbo submission would
      # render step 2 back inside the frame. Nor does autofocus belong in one - it scrolls
      # the embedding page down to the frame on load
      def form_options
        return {data: {turbo: false}, html: {target: "_top"}} if @embed

        {data: {turbo: true, controller: "autofocus register--retry"}}
      end

      # The frame is narrower than the combobox's mobile breakpoint, and its dialog can't
      # escape the frame to be the full-screen picker it's meant to be
      def combobox_options
        @embed ? {mobile_at: "0px"} : {}
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
      # may have moved on. Discarding it shouldn't discard how they arrived - the
      # organization it's attributed to, or the status they came to report. The raw
      # status, since BParam#status answers status_with_owner for an unset one
      def start_over_path
        new_register_path({discard_token: @b_param.id_token, organization_id: organization&.slug,
                           status: @b_param.bike["status"]}.compact)
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
