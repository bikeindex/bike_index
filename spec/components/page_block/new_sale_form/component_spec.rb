# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::NewSaleForm::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {sale:, item:, marketplace_message:} }
  let(:item) { nil }
  let(:marketplace_message) { nil }
  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 16900) }
  let(:current_user) { marketplace_listing.seller }

  context "with marketplace_message" do
    let(:marketplace_message_id) { FactoryBot.create(:marketplace_message, marketplace_listing:).id }
    let(:sale) { Sale.new(seller: current_user, marketplace_message_id:) }

    it "renders" do
      sale.validate
      expect(sale.amount).to be_nil
      expect(sale.validate).to be_truthy
      expect(component).to have_css "div"
      expect(component).to have_text "sold to"
      # Rendering assigns amount
      expect(sale.amount_cents).to eq 16900
    end
  end
end
