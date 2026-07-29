FactoryBot.define do
  factory :registration_sequence_attestation do
    registration_sequence factory: :registration_sequence_active
    owner_email { "owner@example.com" }
    attestation_text { RegistrationSequence::DEFAULT_ATTESTATION_TEXT }
    attested_at { Time.current }
  end
end
