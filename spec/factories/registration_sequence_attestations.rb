FactoryBot.define do
  factory :registration_sequence_attestation do
    registration_sequence factory: :registration_sequence_active
    owner_email { "owner@example.com" }
  end
end
