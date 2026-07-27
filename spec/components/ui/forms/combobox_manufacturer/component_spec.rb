# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::ComboboxManufacturer::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }
  let!(:frame_maker) { FactoryBot.create(:manufacturer, name: "Surly", frame_maker: true) }
  let!(:component_maker) { FactoryBot.create(:manufacturer, name: "Shimano", frame_maker: false) }

  it "renders a manufacturer_id combobox of every manufacturer" do
    expect(component).to have_css("input[type='hidden'][name='manufacturer_id']", visible: :all)
    expect(component).to_not have_css("label", visible: :all, text: /\S/)
    expect(component).to have_css("[role='option'][data-value='#{frame_maker.id}']", text: "Surly", visible: :all)
    expect(component).to have_css("[role='option'][data-value='#{component_maker.id}']", text: "Shimano", visible: :all)
  end

  context "with frame_maker: true" do
    let(:options) { {frame_maker: true} }

    it "renders only frame makers" do
      expect(component).to have_css("[role='option'][data-value='#{frame_maker.id}']", text: "Surly", visible: :all)
      expect(component).not_to have_css("[role='option']", text: "Shimano", visible: :all)
    end
  end

  context "with a custom manufacturers relation" do
    let(:options) { {manufacturers: Manufacturer.frame_makers} }

    it "renders the given manufacturers" do
      expect(component).to have_css("[role='option']", text: "Surly", visible: :all)
      expect(component).not_to have_css("[role='option']", text: "Shimano", visible: :all)
    end
  end

  context "with forwarded options" do
    let(:options) { {name: :cmp_manufacturer_id, value: frame_maker.id} }

    it "forwards name and value to the combobox" do
      expect(component).to have_css("input[type='hidden'][name='cmp_manufacturer_id']", visible: :all)
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Surly']")
    end
  end
end
