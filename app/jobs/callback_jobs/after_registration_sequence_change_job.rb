# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(registration_sequence_id)
      organization_id = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)&.organization_id
      return if organization_id.blank? || RegistrationSequence.active.where(organization_id:).exists?

      # No active sequence leaves no safety rules to agree to, so the registrations waiting on them are finished
      BParam.acknowledgment_pending.with_bike.where(organization_id:).find_each do |b_param|
        BikeServices::Register.finish_acknowledgment(b_param, b_param.created_bike)
      end
    end
  end
end
