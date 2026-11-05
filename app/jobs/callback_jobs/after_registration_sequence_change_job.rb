# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(registration_sequence_id)
      registration_sequence = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)
      return if registration_sequence.blank?

      # nil for the template, which owns its own pending acknowledgments.
      # An active sequence still has rules to agree to, so they're still owed
      organization_id = registration_sequence.organization_id
      return if RegistrationSequence.active.where(organization_id:).exists?

      RegistrationSequenceAcknowledgment.abandon_pending(organization_id)
    end
  end
end
