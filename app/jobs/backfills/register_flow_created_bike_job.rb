# frozen_string_literal: true

module Backfills
  # AfterBikeSaveJob only matched embed_partial registrations before #4423, so a register flow one
  # abandoned for a bike registered some other way still reads as unfinished. Only created_bike_id:
  # the job also attributes the ownership, which isn't a backfill's to rewrite on existing bikes
  class RegisterFlowCreatedBikeJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    def build_enumerator(cursor:)
      active_record_records_enumerator(BParam.step_1_submitted.without_bike, cursor:)
    end

    # The live job only sees brand new bikes - here a bike registered before the registration
    # started is one it couldn't have been abandoned for
    def each_iteration(b_param)
      bike = Bike.where(owner_email: EmailNormalizer.normalize(b_param.email))
        .where("created_at > ?", b_param.created_at).reorder(:created_at)
        .detect { BikeServices::Register.matches_bike?(b_param, it) }
      b_param.update(created_bike_id: bike.id) if bike.present?
    end
  end
end
