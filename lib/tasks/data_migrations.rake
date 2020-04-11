# frozen_string_literal: true

namespace :data do
  namespace :twitter_accounts_state_and_country do
    desc "Migrate state and country fields from names to foreign keys."
    task up: :environment do
      puts "Migrating..."

      TwitterAccount.transaction do
        TwitterAccount.find_each do |ta|
          ta.state_id = State.fuzzy_find(ta[:state])&.id
          ta.country_id = Country.fuzzy_find(ta[:country])&.id
          ta.save
        end
      end

      puts "done."
    end

    desc "Migrate state and country fields from foreign keys to names."
    task down: :environment do
      puts "Migrating..."

      TwitterAccount.transaction do
        TwitterAccount.find_each do |ta|
          ta[:state] = State.find_by(id: ta.state_id)&.abbreviation
          ta[:country] = Country.find_by(id: ta.country_id)&.name
          ta.save
        end
        TwitterAccount.update_all(state_id: nil, country_id: nil)
      end

      puts "done."
    end
  end
end
