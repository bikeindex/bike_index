# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::NewSaleForm::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {currency:, sale:, item:, marketplace_message:} }
  let(:currency) { Currency.default }
  let(:item) { nil }
  let(:marketplace_message) { nil }
  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 16900) }
  let(:current_user) { marketplace_listing.seller }

  context "with marketplace_message" do
    let(:marketplace_message_id) { FactoryBot.create(:marketplace_message, marketplace_listing:).id }
    let(:sale) { Sale.new(seller: current_user, marketplace_message_id:) }

    it "renders" do
      sale.validate
      expect(sale.validate).to be_truthy
      expect(sale.amount_cents).to be_nil

      expect(component).to have_css "div"
      expect(component).to have_button "Record sale"
      # It assigns the marketplace_listing amount_cents as a default
      expect(component).to have_field(name: "sale[amount]", type: "number", with: 169)
    end

    context "with an amount assigned" do
      it "renders" do
        sale.validate
        expect(sale.validate).to be_truthy
        sale.amount_cents = 424200

        expect(component).to have_css "div"
        expect(component).to have_button "Record sale"
        # It assigns the marketplace_listing amount_cents as a default
        expect(component).to have_field(name: "sale[amount]", type: "number", with: 4242)
      end
    end
  end
end
