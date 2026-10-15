# Seed Brakebills' BR bike sticker batch (idempotent).
#
# Called from:
#   - seed_organization_bikes_and_associations.rb (first-boot seed)
#   - bin/docker-entrypoint every sandbox deploy (repair missing data)
#
# Long-lived sandbox/review databases only seed on first boot, so the entrypoint
# re-runs this to (re)create the batch and repair any missing codes or claims.

organization = Organization.find_by_name("Brakebills")
raise "Brakebills organization not found" unless organization.present?

member = User.find_by_email("member@brakebills.edu")
raise "Brakebills member not found" unless member.present?

sticker_batch = BikeStickerBatch.find_or_initialize_by(prefix: "BR", organization:)
sticker_batch.user = member
sticker_batch.stickers_to_create_count = 101
sticker_batch.initial_code_integer = 1
sticker_batch.save!

# Create codes only if the batch is empty (first run)
if sticker_batch.bike_stickers.count == 0
  sticker_batch.create_codes(101, initial_code_integer: 1)
  puts "  Created 101 BR stickers (BR0001-BR0101)"
end

# Claim stickers 1-3 on the stable Load4 bike (idempotent: skip if already claimed)
sticker_bike = organization.bikes.find_by(serial_number: "LOAD4ROHLOFF01")
if sticker_bike.present?
  stickers_to_claim = sticker_batch.bike_stickers.where(code_integer: 1..3).where(bike_id: nil)
  stickers_to_claim.each do |sticker|
    sticker.claim(user: member, bike: sticker_bike)
    puts "  Assigned sticker #{sticker.pretty_code} to bike ##{sticker_bike.id}"
  end
end
