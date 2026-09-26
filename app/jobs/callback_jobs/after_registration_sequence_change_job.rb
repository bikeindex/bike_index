# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(registration_sequence_id)
      organization_id = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)&.organization_id
      return if organization_id.blank? || RegistrationSequence.active.where(organization_id:).exists?

      # No active sequence leaves no safety rules to agree to, so nothing is owed. destroy_all
      # rather than delete_all: each record releases the email it was holding back
      RegistrationSequenceAcknowledgment.pending
        .where(b_param_id: BParam.with_bike.where(organization_id:)).destroy_all
    end
  end
end
