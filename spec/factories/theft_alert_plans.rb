FactoryBot.define do
  factory :theft_alert_plan do
    sequence(:name) { |n| "Theft Alert Plan #{n.to_s.rjust(3, "0")}" }
    sequence(:amount_cents) { |n| n * 100 }
    views { 50_000 }
    duration_days { 7 }
    active { true }
  end
end
