# frozen_string_literal: true

module Backfills
  # Creating a bike from an unfinished b_param still holding flat raises on the renamed enum value
  class FlatHandlebarTypeJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BParam.where(created_bike_id: nil).where("params->'bike'->>'handlebar_type' = 'flat'")
        .find_each do |b_param|
          b_param.update_column(:params, b_param.params.deep_merge("bike" => {"handlebar_type" => "horizontal"}))
        end
    end
  end
end
