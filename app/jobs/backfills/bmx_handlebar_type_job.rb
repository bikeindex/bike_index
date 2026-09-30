# frozen_string_literal: true

module Backfills
  # BMX was removed from HandlebarType, so until they're moved to flat its records read as having
  # no handlebar type
  class BmxHandlebarTypeJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    BMX_VALUE = 1

    def perform
      [Bike, BikeVersion].each do |klass|
        klass.unscoped.where(handlebar_type: BMX_VALUE)
          .in_batches(of: 1_000) { it.update_all(handlebar_type: :flat) }
      end

      # Creating the bike from one of these raises on the unknown enum value
      BParam.where(created_bike_id: nil).where("params->'bike'->>'handlebar_type' = 'bmx'")
        .find_each do |b_param|
          b_param.update_column(:params, b_param.params.deep_merge("bike" => {"handlebar_type" => "flat"}))
        end
    end
  end
end
