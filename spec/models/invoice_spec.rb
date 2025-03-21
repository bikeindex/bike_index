require "rails_helper"

RSpec.describe Invoice, type: :model do
  it_behaves_like "currencyable"

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
      let(:invoice) { Invoice.new(subscription_start_at: Time.current.yesterday - 1.year, amount_due: 0) }
      it "is not active" do
        invoice.set_calculated_attributes
        expect(invoice.end_at).to be_within(100).of invoice.start_at + invoice.subscription_duration
        expect(invoice.expired?).to be_truthy
        expect(invoice.paid_in_full?).to be_truthy
        expect(invoice.future?).to be_falsey
        expect(invoice.was_active?).to be_truthy
      end
    end
    context "future" do
      let(:invoice) { Invoice.new(subscription_start_at: Time.current + 1.hour, amount_due: 0) }
      it "is not active" do
        invoice.set_calculated_attributes
        expect(invoice.expired?).to be_falsey
        expect(invoice.paid_in_full?).to be_truthy
        expect(invoice.future?).to be_truthy
        expect(invoice.was_active?).to be_falsey
      end
    end
    context "endless" do
      let(:invoice) { Invoice.new(subscription_start_at: Time.current.yesterday - 1.year, amount_due: 0, is_endless: true) }
      it "is not active" do
        invoice.set_calculated_attributes
        expect(invoice.end_at).to be < Time.current
        expect(invoice.end_at).to be_within(100).of invoice.start_at + invoice.subscription_duration
        expect(invoice.endless?).to be_truthy
        expect(invoice.expired?).to be_falsey
        expect(invoice.paid_in_full?).to be_truthy
        expect(invoice.future?).to be_falsey
        expect(invoice.was_active?).to be_truthy
      end
    end
  end

  describe "previous_invoice" do
    let(:invoice) { FactoryBot.create(:invoice, start_at: Time.current - 4.years, force_active: true) }
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
      expect(invoice2.subscription_start_at).to be_within(1.minute).of Time.current - 3.years
      expect(invoice2.renewal_invoice?).to be_truthy
      expect(invoice2.previous_invoice).to eq invoice
      expect(invoice3.subscription_start_at).to be_within(1.minute).of Time.current - 2.years
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
      let(:invoice) { FactoryBot.create(:invoice, subscription_start_at: Time.current - 4.years, force_active: true) }
      let(:organization_feature) { FactoryBot.create(:organization_feature, kind: "standard") }
      let(:organization_feature_one_time) { FactoryBot.create(:organization_feature_one_time) }
      it "returns invoice" do
        expect(organization.enabled_feature_slugs).to eq([])
        invoice.update(organization_feature_ids: [organization_feature.id, organization_feature_one_time.id])
        expect(invoice.organization_features.pluck(:id)).to match_array([organization_feature.id, organization_feature_one_time.id])
        invoice2 = invoice.create_following_invoice
        expect(invoice2.is_a?(Invoice)).to be_truthy
        expect(invoice2.active?).to be_falsey
        expect(invoice2.renewal_invoice?).to be_truthy
        expect(invoice.create_following_invoice).to eq invoice2
        expect(invoice.following_invoice).to eq invoice2
        expect(invoice2.following_invoice).to be_nil
        expect(invoice2.organization_features.pluck(:id)).to eq([organization_feature.id])
        expect(invoice2.feature_slugs).to eq([])
      end
    end
  end

  describe "law_enforcement_functionality_invoice" do
    let(:amount_due) { 0 }
    let(:organization_feature) { FactoryBot.create(:organization_feature, name: "Law Enforcement", feature_slugs: %w[unstolen_notifications additional_registration_information]) }
    let(:organization) { FactoryBot.create(:organization, kind: :law_enforcement) }
    let!(:invoice) do
      FactoryBot.create(:invoice_with_payment,
        organization: organization,
        amount_due_cents: amount_due,
        is_endless: true)
    end
    before do
      invoice.update(organization_feature_ids: organization_feature.id)
      organization.update(updated_at: Time.current)
    end
    it "is true" do
      expect(invoice.reload.paid_money_in_full?).to be_falsey
      expect(invoice.feature_slugs).to eq(%w[unstolen_notifications additional_registration_information])
      expect(invoice.law_enforcement_functionality_invoice?).to be_truthy
      expect(organization.reload.paid_money?).to be_falsey
      expect(organization.law_enforcement_features_enabled?).to be_truthy
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(organization)).to be_falsey
    end
    context "paid_money_in_full" do
      let(:amount_due) { 5000 }
      it "is true" do
        expect(invoice.paid_money_in_full?).to be_truthy
        expect(invoice.law_enforcement_functionality_invoice?).to be_truthy
        expect(organization.reload.paid_money?).to be_truthy
        expect(organization.law_enforcement_features_enabled?).to be_truthy
        expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(organization)).to be_falsey
      end
    end
  end

  describe "child_enabled_feature_slugs" do
    let(:invoice) { FactoryBot.create(:invoice) }
    it "rejects unmatching feature slugs" do
      invoice.update(child_enabled_feature_slugs_string: ["passwordless_users"])
      expect(invoice.child_enabled_feature_slugs).to eq([])
    end
    context "with organization features" do
      let(:organization_feature) { FactoryBot.create(:organization_feature, feature_slugs: %w[passwordless_users reg_phone reg_address]) }
      it "permits matching organization feature slugs" do
        invoice.organization_feature_ids = [organization_feature.id]
        invoice.reload
        expect(invoice.feature_slugs).to eq(%w[passwordless_users reg_phone reg_address])
        expect(invoice.child_enabled_feature_slugs).to be_blank
        invoice.update(child_enabled_feature_slugs_string: %w[passwordless_users reg_phone reg_address])
        invoice.reload
        expect(invoice.child_enabled_feature_slugs).to eq(%w[passwordless_users reg_phone reg_address])
        invoice.update(child_enabled_feature_slugs_string: "stuff, passwordless_users, reg_address, show_partial_registrations, reg_address, \n")
        expect(invoice.child_enabled_feature_slugs).to eq(%w[passwordless_users reg_address])
      end
    end
  end

  describe "organization_feature_ids" do
    let(:invoice) { FactoryBot.create(:invoice, amount_due_cents: nil, subscription_start_at: Time.current - 1.week) }
    let(:organization_feature) { FactoryBot.create(:organization_feature, amount_cents: 100_000) }
    let(:organization_feature2) { FactoryBot.create(:organization_feature) }
    let(:organization_feature_one_time) { FactoryBot.create(:organization_feature_one_time, name: "one Time Feature") }
    it "adds the organization feature ids and updates amount_due_cents" do
      expect(invoice.amount_due_cents).to be_nil

      invoice.update(organization_feature_ids: organization_feature.id, amount_due_cents: 0)
      expect(invoice.paid_in_full?).to be_truthy # Because it was just overridden
      expect(invoice.active?).to be_truthy
      expect(invoice.organization_features.pluck(:id)).to eq([organization_feature.id])

      invoice.update(organization_feature_ids: " #{organization_feature.id}, #{organization_feature_one_time.id}, #{organization_feature_one_time.id}, xxxxx,#{organization_feature.id}")
      expect(invoice.organization_features.pluck(:id)).to match_array([organization_feature.id, organization_feature_one_time.id] * 2)

      invoice.organization_feature_ids = [organization_feature_one_time.id, organization_feature2.id, "xxxxx"]
      expect(invoice.organization_features.pluck(:id)).to match_array([organization_feature2.id, organization_feature_one_time.id])

      expect { organization.save }.to change { UpdateOrganizationAssociationsJob.jobs.count }.by(1)
      expect(organization.enabled_feature_slugs).to eq([])
    end
  end

  describe "two invoices" do
    let(:organization_feature1) { FactoryBot.create(:organization_feature, feature_slugs: ["bike_search"]) }
    let(:organization_feature2) { FactoryBot.create(:organization_feature, feature_slugs: ["extra_registration_number"]) }
    let(:invoice1) { FactoryBot.create(:invoice, amount_due_cents: 0, subscription_start_at: Time.current - 1.week) }
    let(:organization) { invoice1.organization }
    let(:invoice2) { FactoryBot.create(:invoice_with_payment, amount_due_cents: 10000, subscription_start_at: Time.current - 1.day, organization: organization) }
    it "adds the organization features" do
      invoice1.update(organization_feature_ids: [organization_feature1.id])
      expect(invoice1.paid_in_full?).to be_truthy
      expect(invoice1.paid_money_in_full?).to be_falsey

      organization.update(updated_at: Time.current)
      organization.reload
      expect(organization.enabled_feature_slugs).to eq(["bike_search"])
      expect(organization.paid?).to be_truthy
      expect(organization.paid_money?).to be_falsey

      invoice2.update(organization_feature_ids: [organization_feature2.id])
      invoice2.reload
      expect(invoice2.amount_due_cents).to eq 10000
      expect(invoice2.payments.count).to eq 1
      expect(invoice2.payments.first.amount_cents).to eq 10000
      expect(invoice2.payments.first.organization_id).to eq organization.id
      expect(invoice2.paid_in_full?).to be_truthy
      expect(invoice2.paid_money_in_full?).to be_truthy

      organization.update(updated_at: Time.current)
      organization.reload
      expect(organization.enabled_feature_slugs).to match_array %w[bike_search extra_registration_number]
      expect(organization.paid?).to be_truthy
      expect(organization.paid_money?).to be_truthy
    end
  end
end
