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

  it "renders a checkbox per feature, and the totals admin--invoice-form fills in" do
    expect(component).to have_field("organization_feature_ids_#{organization_feature.id}", type: "checkbox")
    expect(component).to have_link("Parking notifications")
    %w[oneTimeCost recurringCost totalCost discountCost].each do |total|
      expect(component).to have_css("[data-admin--invoice-form-target='#{total}']")
    end
  end

  # The controller totals from these rather than from the DOM text
  it "gives each checkbox its amount, id and whether it recurs" do
    checkbox = component.at_css("[data-admin--invoice-form-target='feature']")
    expect(checkbox["data-amount"]).to eq organization_feature.amount.to_s
    expect(checkbox["data-id"]).to eq organization_feature.id.to_s
    expect(checkbox["data-recurring"]).to eq "true"
  end

  context "with an endless invoice" do
    let(:invoice) { FactoryBot.create(:invoice, organization:, is_endless: true) }

    it "hides the coverage-ends field" do
      expect(component.at_css("[data-admin--invoice-form-target='endsAt']")["class"]).to include("tw:hidden!")
    end
  end
end
