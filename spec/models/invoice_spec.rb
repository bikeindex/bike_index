require "spec_helper"

RSpec.describe Invoice, type: :model do
  let(:organization) { invoice.organization }

  describe "friendly_find" do
    let!(:invoice) { FactoryBot.create(:invoice) }
    it "finds or doesn't appropriately" do
      expect(Invoice.friendly_find(invoice.id)).to eq invoice
      expect(Invoice.friendly_find("Invoice ##{invoice.id}")).to eq invoice
      expect(Invoice.friendly_find("Invoice 82812812")).to be_nil
    end
  end

  describe "set_calculated_attributes" do
    context "expired paid_in_full" do
      let(:invoice) { Invoice.new(subscription_start_at: Time.now.yesterday - 1.year, amount_due: 0) }
      it "is not active" do
        invoice.set_calculated_attributes
        expect(invoice.expired?).to be_truthy
        expect(invoice.paid_in_full?).to be_truthy
        expect(invoice.was_active?).to be_truthy
      end
    end
  end

  describe "previous_invoice" do
    let(:invoice) { FactoryBot.create(:invoice, start_at: Time.now - 4.years, force_active: true) }
    let(:invoice2) { invoice.create_following_invoice }
    let(:invoice3) { invoice2.create_following_invoice }
    it "returns correct invoices" do
      expect(invoice.previous_invoice).to be_nil
      expect(invoice2.subscription_first_invoice).to eq invoice
      invoice2.update_attribute :force_active, true # So we can create another invoice after
      expect(invoice2.expired?).to be_truthy
      expect(invoice2.active?).to be_falsey
      expect(invoice2.was_active?).to be_truthy
      expect(invoice3.subscription_first_invoice).to eq invoice
      expect(invoice2.subscription_start_at).to be_within(1.minute).of Time.now - 3.years
      expect(invoice2.renewal_invoice?).to be_truthy
      expect(invoice2.previous_invoice).to eq invoice
      expect(invoice3.subscription_start_at).to be_within(1.minute).of Time.now - 2.years
      expect(invoice3.previous_invoice).to eq invoice2
    end
  end

  describe "create_following_invoice" do
    context "with not active invoice" do
      let(:invoice) { FactoryBot.create(:invoice, is_active: false) }
      it "returns nil" do
        expect(invoice.renewal_invoice?).to be_falsey
        expect(invoice.active?).to be_falsey
        expect(invoice.create_following_invoice).to be_nil
      end
    end
    context "with active invoice" do
      let(:invoice) { FactoryBot.create(:invoice, subscription_start_at: Time.now - 4.years, force_active: true) }
      let(:paid_feature) { FactoryBot.create(:paid_feature, kind: "standard") }
      let(:paid_feature_one_time) { FactoryBot.create(:paid_feature_one_time) }
      it "returns invoice" do
        expect(organization.paid_feature_slugs).to eq([])
        invoice.update_attributes(paid_feature_ids: [paid_feature.id, paid_feature_one_time.id])
        expect(invoice.paid_features.pluck(:id)).to match_array([paid_feature.id, paid_feature_one_time.id])
        invoice2 = invoice.create_following_invoice
        expect(invoice2.is_a?(Invoice)).to be_truthy
        expect(invoice2.active?).to be_falsey
        expect(invoice2.renewal_invoice?).to be_truthy
        expect(invoice.create_following_invoice).to eq invoice2
        expect(invoice.following_invoice).to eq invoice2
        expect(invoice2.following_invoice).to be_nil
        expect(invoice2.paid_features.pluck(:id)).to eq([paid_feature.id])
        expect(invoice2.feature_slugs).to eq([])
      end
    end
  end

  describe "paid_feature_ids" do
    let(:invoice) { FactoryBot.create(:invoice, amount_due_cents: nil, subscription_start_at: Time.now - 1.week) }
    let(:paid_feature) { FactoryBot.create(:paid_feature, amount_cents: 100_000) }
    let(:paid_feature2) { FactoryBot.create(:paid_feature) }
    let(:paid_feature_one_time) { FactoryBot.create(:paid_feature_one_time, name: "one Time Feature") }
    it "adds the paid feature ids and updates amount_due_cents" do
      expect(invoice.amount_due_cents).to be_nil
      invoice.update_attributes(paid_feature_ids: paid_feature.id)
      invoice.reload
      invoice.update_attributes(amount_due_cents: 0)
      expect(invoice.paid_in_full?).to be_truthy # Because it was just overridden
      expect(invoice.active?).to be_truthy
      expect(invoice.paid_features.pluck(:id)).to eq([paid_feature.id])
      invoice.update_attributes(paid_feature_ids: " #{paid_feature.id}, #{paid_feature_one_time.id}, #{paid_feature_one_time.id}, xxxxx,#{paid_feature.id}")
      invoice.reload
      expect(invoice.paid_features.pluck(:id)).to match_array([paid_feature.id, paid_feature_one_time.id] * 2)
      invoice.paid_feature_ids = [paid_feature_one_time.id, paid_feature2.id, "xxxxx"]
      invoice.reload
      expect(invoice.paid_features.pluck(:id)).to match_array([paid_feature2.id, paid_feature_one_time.id])
      # TODO: Rails 5 update - Have to manually deal with updating because rspec doesn't correctly manage after_commit
      organization.update_attributes(updated_at: Time.now)
      organization.reload
      expect(organization.paid_feature_slugs).to eq([])
    end
  end

  describe "two invoices" do
    let(:paid_feature1) { FactoryBot.create(:paid_feature, feature_slugs: ["bike_search"]) }
    let(:paid_feature2) { FactoryBot.create(:paid_feature, feature_slugs: ["reg_secondary_serial"]) }
    let(:invoice1) { FactoryBot.create(:invoice, amount_due_cents: 0, subscription_start_at: Time.now - 1.week) }
    let(:organization) { invoice1.organization }
    let(:invoice2) { FactoryBot.build(:invoice, amount_due_cents: 0, subscription_start_at: Time.now - 1.day, organization: organization) }
    it "adds the paid features" do
      invoice1.update_attributes(paid_feature_ids: [paid_feature1.id])
      # TODO: Rails 5 update
      organization.update_attributes(updated_at: Time.now)
      expect(organization.paid_feature_slugs).to eq(["bike_search"])
      invoice2.save
      invoice2.update_attributes(paid_feature_ids: [paid_feature2.id])
      organization.update_attributes(updated_at: Time.now)
      expect(organization.paid_feature_slugs).to match_array %w[bike_search reg_secondary_serial]
    end
  end
end
