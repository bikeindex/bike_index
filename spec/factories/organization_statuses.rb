FactoryBot.define do
  factory :organization_status do
    start_at { Time.current - 5.minutes }
    pos_kind { :lightspeed_pos }
    organization { FactoryBot.create(:organization, pos_kind: pos_kind) }
  end
end
