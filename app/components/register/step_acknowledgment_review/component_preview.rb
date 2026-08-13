# frozen_string_literal: true

module Register
  module StepAcknowledgmentReview
    # The acknowledgment the rule pages end at, rendered from an organization's live sequence
    class ComponentPreview < ApplicationComponentPreview
      def default
        return production_notice("registration") if Rails.env.production?

        sequence = preview_sequence
        pages = ::BikeServices::Register.sequence_pages(sequence)
        return missing_notice("a registration sequence with pages") if pages.none?

        b_param = preview_b_param(sequence, pages.map(&:id))
        render(Register::StepAcknowledgmentReview::Component.new(sequence:, b_param:, current_user: lookbook_user,
          steps: ::BikeServices::Register.steps(b_param, sequence:)))
      end

      private

      # Every page acknowledged - the review is only reachable once they all are
      def preview_b_param(sequence, acknowledged_page_ids)
        ::BParam.new(origin: "register_flow", params: {
          bike: {owner_email: lookbook_user&.email, cycle_type: "e-scooter",
                 creation_organization_id: sequence.organization_id},
          registration_sequence: {id: sequence.id, acknowledged_page_ids:}
        }.as_json)
      end

      # The live template stands in where no organization has activated a sequence
      def preview_sequence = ::RegistrationSequence.active_or_template_for(lookbook_organization, kind: "e_vehicle")
    end
  end
end
