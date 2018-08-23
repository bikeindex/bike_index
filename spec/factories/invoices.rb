FactoryGirl.define do
  factory :invoice do
    organization { FactoryGirl.create(:organization) }
    amount_due_cents 100_000
  end
end
