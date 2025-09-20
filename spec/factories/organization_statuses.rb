FactoryBot.define do
  factory :organization_status do
    start_at { 5.minutes.ago }
    pos_kind { :lightspeed_pos }
    organization { FactoryBot.create(:organization, pos_kind: pos_kind) }
  end
end
