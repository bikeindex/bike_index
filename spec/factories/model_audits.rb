FactoryBot.define do
  factory :model_audit do
    sequence(:frame_model) { |n| "Model #{n}" }
    manufacturer { FactoryBot.create(:manufacturer) }
    propulsion_type { :throttle }
  end
end
