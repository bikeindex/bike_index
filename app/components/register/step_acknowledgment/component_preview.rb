# frozen_string_literal: true

module Register
  module StepAcknowledgment
    # One page of an organization's e-vehicle rules, rendered from its live sequence
    class ComponentPreview < ApplicationComponentPreview
      # Where the flow explains why these pages appeared at all
      # @label Step 1 of 4
      def step_1_of_4
        acknowledgment_page(0)
      end

      # The last of the rule pages, with only the review left after it
      # @label Step 3 of 4
      def step_3_of_4
        acknowledgment_page(2)
      end

      # Revisited from the review, showing what was agreed to rather than asking again
      def already_acknowledged
        acknowledgment_page(0, acknowledged: true)
      end

      private

      def acknowledgment_page(index, acknowledged: false)
        return production_notice("registration") if Rails.env.production?

        sequence = preview_sequence
        page = ::BikeServices::Register.sequence_pages(sequence)[index]
        return missing_notice("a registration sequence with #{index + 1} pages") if page.blank?

        b_param = preview_b_param(sequence, acknowledged ? [page.id] : [])
        render(Register::StepAcknowledgment::Component.new(sequence:, b_param:,
          step: ::BikeServices::Register.step_for_page_index(index),
          steps: ::BikeServices::Register.steps(b_param, sequence:)))
      end

      # The pages only appear for an e-vehicle registered with the organization
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
