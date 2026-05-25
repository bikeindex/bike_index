# frozen_string_literal: true

module Backfills
  class CountryNetherlandsAntillesToCuracaoJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    TABLES = [AddressRecord, ExternalRegistryBike, ParkingNotification, SocialAccount].freeze

    def perform
      antilles = Country.find_by(iso: "AN")
      return if antilles.nil?

      curacao = Country.where(iso: "CW", name: "Curaçao").first_or_create!

      TABLES.each { |klass| klass.where(country_id: antilles.id).update_all(country_id: curacao.id) }
      StolenRecord.unscoped.where(country_id: antilles.id).update_all(country_id: curacao.id)

      antilles.destroy
    end
  end
end
