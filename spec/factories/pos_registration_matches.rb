FactoryBot.define do
  # A customer's own registration of a bike their shop's POS registered to them, grouped and matched the way
  # registration and DuplicateBikeFinderJob do it
  factory :pos_registration_match do
    transient do
      user { FactoryBot.create(:user_confirmed) }
      manufacturer { FactoryBot.create(:manufacturer) }
      serial_number { "WTU123C4567" }
    end
    pos_bike do
      FactoryBot.create(:bike_lightspeed_pos, owner_email: user.email, manufacturer:, serial_number:, created_at: Time.current - 30.days)
    end
    bike do
      FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer:, serial_number:, creation_state_origin: "web",
        claimed_at: Time.current)
    end

    after(:build) do |pos_registration_match|
      [pos_registration_match.pos_bike, pos_registration_match.bike].each(&:create_normalized_serial_segments)
      BikeJobs::DuplicateBikeFinderJob.new.perform(pos_registration_match.bike.id)
      pos_registration_match.duplicate_bike_group_id = pos_registration_match.bike.normalized_serial_segments
        .where(segment: pos_registration_match.bike.serial_normalized_no_space).pick(:duplicate_bike_group_id)
    end
  end
end
