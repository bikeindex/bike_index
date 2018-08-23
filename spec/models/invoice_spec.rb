require 'rails_helper'

RSpec.describe Invoice, type: :model do
  describe "calculated_attributes" do
    let(:first_date) { Time.now - 2.years }
    let(:paid_feature) { FactoryGirl.create(:paid_feature, upfront_cents: 50_000, recurring_cents: 10_000) }
    let(:invoice) { FactoryGirl.create(:invoice, subscription_end_at: nil, subscription_start_at: first_date) }
    let(:organization) { invoice.organization }
    it "sets useful things" do
      invoice.reload
      expect(invoice.paid_in_full?).to be_falsey
      expect(invoice.first_invoice?).to be_truthy
      expect(invoice.subscription_start_at).to be_within(1.second).of first_date
      expect(invoice.subscription_end_at).to be_within(1.second).of first_date + 1.year
      expect(invoice.features_at_start_cents).to eq 50_000
      expect(invoice.features_at_start_recurring_cents).to eq 10_000
      expect(invoice.amount_due_cents).to eq 50_000
      expect do
        FactoryGirl.create(:payment, organization: organization, invoice: invoice2, amount_cents: 50_000)
      end.to change(Invoice, :count).by 1

      expect(Invoice.paid_in_full.pluck(:id)).to eq([invoice.id])
      invoice2 = Invoice.last
      expect(invoice)
      expect(invoice2.paid_in_full?).to be_falsey
      expect(invoice2.organization).to eq organization
      expect(invoice2.subscription_start_at).to be_within(1.second).of invoice.subscription_end_at
      expect(invoice2.subscription_end_at).to be_within(1.second).of invoice.subscription_end_at + 1.year
      expect(invoice2.features_at_start_cents).to eq 50_000
      expect(invoice2.features_at_start_recurring_cents).to eq 10_000
      expect(invoice.amount_due_cents).to eq 10_000
    end
  end
end
