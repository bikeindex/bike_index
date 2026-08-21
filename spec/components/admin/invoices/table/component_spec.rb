# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Invoices::Table::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Cool Bikes") }
  let(:invoice) { FactoryBot.create(:invoice, organization:, amount_due: 1000) }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(invoices: [invoice], **options)) }

  it "links the invoice, and drops the organization column" do
    expect(component).to have_link(href: "/admin/organizations/#{organization.to_param}/invoices/#{invoice.to_param}/edit")
    expect(component).to_not have_link("Cool Bikes")
    expect(component).to have_content("Discount")
  end

  context "display_organization" do
    let(:options) { {display_organization: true} }

    it "links the organization" do
      expect(component).to have_link("Cool Bikes", href: "/admin/organizations/#{organization.to_param}")
    end

    context "with the organization deleted" do
      # the association is cached from creating the invoice, so it has to be re-read
      before { invoice.tap { organization.destroy }.reload }

      it "still renders the row, saying the organization is gone" do
        expect(component).to have_content("organization is deleted!")
      end
    end
  end

  context "skip_discount_due" do
    let(:options) { {skip_discount_due: true} }

    it "drops the money columns" do
      expect(component).to_not have_content("Discount")
    end
  end
end
