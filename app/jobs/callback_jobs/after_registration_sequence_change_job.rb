# frozen_string_literal: true

module CallbackJobs
  class AfterRegistrationSequenceChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(registration_sequence_id)
      organization_id = RegistrationSequence.with_deleted.find_by(id: registration_sequence_id)&.organization_id
      return if organization_id.blank? || RegistrationSequence.active.where(organization_id:).exists?

      BParam.acknowledgment_pending.with_bike.where(organization_id:).find_each do |b_param|
        BikeServices::Register.drop_pending_acknowledgment(b_param)
      end
    end
  end
end
