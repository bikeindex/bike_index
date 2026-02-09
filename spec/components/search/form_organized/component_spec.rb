# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::FormOrganized::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {target_search_path:, interpreted_params:} }
  let(:target_search_path) { "/bikes" }
  let(:interpreted_params) { {} }

  it "renders form with search fields" do
    expect(component).to have_css("form#Search_Form[data-turbo='false']")
    expect(component).to have_css("input[name='search_email']")
    expect(component).to have_css("input[name='serial']")
    expect(component).to have_css("input[name='search_stickers']", visible: :hidden)
    expect(component).to have_css("input[name='search_address']", visible: :hidden)
    expect(component).to have_css("input[name='search_secondary']", visible: :hidden)
    expect(component).to have_css("input[name='search_model_audit_id']", visible: :hidden)
  end

  context "with interpreted_params values" do
    let(:interpreted_params) do
      {
        search_email: "test@example.com",
        raw_serial: "ABC123",
        serial: "ABC123",
        search_stickers: "sticker1",
        search_address: "123 Main St"
      }
    end

    it "renders with values filled in" do
      expect(component).to have_field("search_email", with: "test@example.com")
      expect(component).to have_field("serial", with: "ABC123")
      expect(component).to have_css("input[name='search_stickers'][value='sticker1']", visible: :hidden)
      expect(component).to have_css("input[name='search_address'][value='123 Main St']", visible: :hidden)
    end
  end

  context "with skip_serial_field" do
    let(:options) { {target_search_path:, interpreted_params:, skip_serial_field: true} }

    it "renders without serial field" do
      expect(component).to have_css("form#Search_Form")
      expect(component).to have_css("input[name='search_email']")
      expect(component).not_to have_css("input[name='serial']")
    end
  end

  context "when serial looks like not a serial" do
    let(:interpreted_params) { {raw_serial: "xyz", serial: nil} }

    it "renders warning alert" do
      expect(component).to have_css("[role='alert']", text: /doesn't look like a serial/)
    end
  end

  context "when serial is valid" do
    let(:interpreted_params) { {raw_serial: "ABC123456", serial: "ABC123456"} }

    it "does not render warning alert" do
      expect(component).not_to have_css("[role='alert']")
    end
  end
end
