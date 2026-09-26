# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(registration_sequence_id)
      organization_id = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)&.organization_id
      return if organization_id.blank? || RegistrationSequence.active.where(organization_id:).exists?

      RegistrationSequenceAcknowledgment.abandon_pending(organization_id)
    end
  end
end
