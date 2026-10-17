FactoryBot.define do
  factory :registration_sequence_acknowledgment do
    registration_sequence factory: :registration_sequence_active
    owner_email { "owner@example.com" }
    acknowledged_at { Time.current }

    factory :registration_sequence_acknowledgment_pending do
      acknowledged_at { nil }
    end
  end
end
