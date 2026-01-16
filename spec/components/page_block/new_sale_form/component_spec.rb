# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::NewSaleForm::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {sale:, item:, marketplace_message:} }
  let(:sale) { nil }
  let(:item) { nil }
  let(:marketplace_message) { nil }

  context "with marketplace_message" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message) }

    it "renders" do
      expect(component).to have_css "div"
      expect(component).to have_text "save"
    end
  end
end
