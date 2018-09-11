FactoryGirl.define do
  factory :invoice do
    organization { FactoryGirl.create(:organization) }
    amount_due_cents 100_000
    factory :invoice_paid do
      amount_due 0
      subscription_start_at { Time.now - 1.week }
    end
  end
end
