FactoryBot.define do
  factory :invoice do
    organization { FactoryBot.create(:organization) }
    amount_due_cents { 100_000 }
    factory :invoice_paid do
      amount_due { 0 }
      start_at { Time.current - 1.week }
    end
    factory :invoice_with_payment do
      amount_due_cents { 50000 }
      start_at { Time.current - 1.week }

      after(:create) do |invoice, _evaluator|
        FactoryBot.create(:payment, amount_cents: invoice.amount_due_cents, invoice: invoice)
      end
    end
  end
end
