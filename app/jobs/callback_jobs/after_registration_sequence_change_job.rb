# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "low_priority"

    def perform(registration_sequence_id)
      organization_id = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)&.organization_id
      return if organization_id.blank? || RegistrationSequence.active.where(organization_id:).exists?

      # No active sequence leaves no safety rules to agree to, so the registrations waiting on them are finished
      BParam.acknowledgment_pending.where(organization_id:).find_each do |b_param|
        b_param.update(params: b_param.params.except("acknowledgment_pending"))
      end
    end
  end
end
