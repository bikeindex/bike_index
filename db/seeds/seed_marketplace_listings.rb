# Seed marketplace listings for the marketplace index.
# "Promoted" listings are those whose seller has an active membership -
# they're partitioned to the top of /search/marketplace under a "Promoted" header.
require "factory_bot_rails"
FactoryBot.reload

def seed_marketplace_bike
  FactoryBot.create(:bike, :with_ownership_claimed,
    manufacturer: Manufacturer.frame_makers.sample,
    primary_activity: PrimaryActivity.where(family: false).order("RANDOM()").first)
end

# --- 6 standard for-sale listings ---
standard_locations = %i[davis chicago los_angeles new_york amsterdam davis]
standard_locations.each_with_index do |address_in, i|
  FactoryBot.create(:marketplace_listing, :for_sale,
    item: seed_marketplace_bike, address_in:, amount_cents: (250 + i * 125) * 100)
end
puts "  Created #{standard_locations.count} standard marketplace listings"

# --- 4 promoted listings (seller has an active membership) ---
promoted_locations = %i[chicago los_angeles new_york davis]
promoted_locations.each_with_index do |address_in, i|
  seller = FactoryBot.create(:user_confirmed)
  FactoryBot.create(:membership, user: seller)
  FactoryBot.create(:marketplace_listing, :for_sale,
    seller:, item: seed_marketplace_bike, address_in:, amount_cents: (900 + i * 200) * 100)
end
puts "  Created #{promoted_locations.count} promoted marketplace listings"

puts "Marketplace listings seeded successfully!"
