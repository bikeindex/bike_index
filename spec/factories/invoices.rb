# == Schema Information
#
# Table name: invoices
#
#  id                          :integer          not null, primary key
#  amount_due_cents            :integer
#  amount_paid_cents           :integer
#  child_enabled_feature_slugs :jsonb
#  currency_enum               :integer
#  force_active                :boolean          default(FALSE), not null
#  is_active                   :boolean          default(FALSE), not null
#  is_endless                  :boolean          default(FALSE)
#  notes                       :text
#  subscription_end_at         :datetime
#  subscription_start_at       :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  first_invoice_id            :integer
#  organization_id             :integer
#
# Indexes
#
#  index_invoices_on_first_invoice_id  (first_invoice_id)
#  index_invoices_on_organization_id   (organization_id)
#
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
