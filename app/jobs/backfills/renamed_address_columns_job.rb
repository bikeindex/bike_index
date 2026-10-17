# frozen_string_literal: true

module Backfills
  # Copy zipcode and state_id into postal_code and region_record_id, which are replacing them.
  # logged_searches has 40M+ rows, so walk the primary key in fixed ranges - no count or id pluck
  # like the active_record enumerators do - and only write the rows that differ
  class RenamedAddressColumnsJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    MODELS = {"SocialAccount" => SocialAccount, "LoggedSearch" => LoggedSearch}.freeze
    BATCH_SIZE = 10_000

    # The cursor is the range's first id, so a resumed run redoes the range it stopped on
    def build_enumerator(model_name, cursor:)
      (cursor || 0).step(MODELS.fetch(model_name).maximum(:id).to_i, BATCH_SIZE).lazy.map { [it, it] }
    end

    def each_iteration(start_id, model_name)
      MODELS.fetch(model_name).where(id: start_id...(start_id + BATCH_SIZE))
        .where("postal_code IS DISTINCT FROM zipcode OR region_record_id IS DISTINCT FROM state_id")
        .update_all("postal_code = zipcode, region_record_id = state_id")
    end
  end
end
