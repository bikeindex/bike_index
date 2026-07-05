namespace :setup do
  desc "Reset Autocomplete"
  task reset_autocomplete: :environment do
    AutocompleteLoaderJob.new.perform(nil, true)
  end

  desc "Load counts" # This is a rake task so it can be loaded from bin/update
  task load_counts: :environment do
    UpdateCountsJob.new.perform
  end

  desc "refresh reference data (manufacturers, primary activities, components) from bike_data GitHub spreadsheets"
  task import_spreadsheets: :environment do
    # Run inline rather than enqueue: seeding's later steps need this data present
    Spreadsheets::ImporterJob.new.perform
  end

  desc "Migrate an existing seeded Hogwarts organization to Brakebills (rename, logo, email snippets, owner emails)"
  task backfill_brakebills: :environment do
    organization = Organization.friendly_find("hogwarts") || Organization.friendly_find("brakebills")
    raise "No Hogwarts/Brakebills organization found" if organization.blank?

    # Reset short_name so the slug recomputes from the new name; keep previous_slug so old URLs resolve
    if organization.name != "Brakebills"
      organization.update!(name: "Brakebills", short_name: "Brakebills", previous_slug: "hogwarts")
      puts "Renamed organization ##{organization.id} to Brakebills (slug: #{organization.slug})"
    end

    File.open(Rails.root.join("db/seeds/images/brakebills.png")) { |file| organization.avatar = file }
    organization.save!
    puts "Set Brakebills logo"

    # Re-applies the reworded mail snippets and the avatar-backed email header
    load Rails.root.join("db/seeds/seed_organized_emails.rb").to_s

    %w[alice bob carol dave eve frank grace heidi ivan judy kevin laura mike nora oscar].each do |name|
      Ownership.where(owner_email: "#{name}@bikeindex.org").update_all(owner_email: "#{name}@brakebills.edu")
      Bike.where(owner_email: "#{name}@bikeindex.org").update_all(owner_email: "#{name}@brakebills.edu")
    end
    puts "Backfilled Brakebills owner emails"
  end
end
