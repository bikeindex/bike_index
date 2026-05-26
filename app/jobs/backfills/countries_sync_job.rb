# frozen_string_literal: true

module Backfills
  class CountriesSyncJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    TABLES = [AddressRecord, ExternalRegistryBike, ParkingNotification, SocialAccount].freeze

    def perform
      sync_names
      migrate_netherlands_antilles
    end

    private

    def sync_names
      StatesAndCountries.countries.each do |attrs|
        country = Country.find_by(iso: attrs[:iso])
        next if country.nil? || country.name == attrs[:name]
        country.update!(name: attrs[:name])
      end
    end

    def migrate_netherlands_antilles
      antilles = Country.find_by(iso: "AN")
      return if antilles.nil?

      curacao = Country.where(iso: "CW", name: "Curaçao").first_or_create!

      TABLES.each { |klass| klass.where(country_id: antilles.id).update_all(country_id: curacao.id) }
      StolenRecord.unscoped.where(country_id: antilles.id).update_all(country_id: curacao.id)

      antilles.destroy
    end
  end
end
