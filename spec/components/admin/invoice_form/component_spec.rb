# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::InvoiceForm::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:invoice) { organization.invoices.new }
  let!(:organization_feature) { FactoryBot.create(:organization_feature, name: "Parking notifications") }
  let(:component) do
    render_inline(described_class.new(organization:, invoice:,
      organization_features: OrganizationFeature.name_ordered))
  end

  # The invoice is only rendered, so it mustn't come back with the defaults written onto it
  it "defaults the coverage dates without assigning them to the invoice" do
    expect(component.at_css("#invoice_start_at")["value"]).to be_present
    expect(component.at_css("#invoice_end_at")["value"]).to be_present
    expect(invoice.subscription_start_at).to be_nil
    expect(invoice.subscription_end_at).to be_nil
  end

  it "renders a checkbox per feature, and the totals the admin bundle fills in" do
    expect(component).to have_field("organization_feature_ids_#{organization_feature.id}", type: "checkbox")
    expect(component).to have_link("Parking notifications")
    expect(component).to have_css("#oneTimeCost")
    expect(component).to have_css("#recurringCost")
    expect(component).to have_css("#totalCost")
  end

  context "with an endless invoice" do
    let(:invoice) { FactoryBot.create(:invoice, organization:, is_endless: true) }

    it "collapses the coverage-ends field" do
      expect(component).to have_css("#subscriptionEndsAt.collapse")
      expect(component).to_not have_css("#subscriptionEndsAt.show")
    end
  end
end
