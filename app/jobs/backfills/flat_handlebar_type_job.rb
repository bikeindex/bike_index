# frozen_string_literal: true

module Backfills
  # Building a bike from an unfinished b_param still holding flat fails with "Handlebar type is not valid"
  class FlatHandlebarTypeJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BParam.where(created_bike_id: nil).where("params->'bike'->>'handlebar_type' = 'flat'")
        .update_all(%q(params = jsonb_set(params, '{bike,handlebar_type}', '"horizontal"')))
    end
  end
end
