# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::ComboboxManufacturer::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }
  let(:async_src) { component.css("[data-hw-combobox-async-src-value]").first["data-hw-combobox-async-src-value"] }

  it "renders a manufacturer_id combobox that autocompletes every manufacturer, accepting free text" do
    expect(component).to have_css("input[type='hidden'][name='manufacturer_id']", visible: :all)
    expect(component).to_not have_css("label.hw-combobox__label", visible: :all, text: /\S/)
    placeholder = component.css("input[role='combobox']").first["placeholder"]
    expect(described_class::PLACEHOLDER_NAMES).to include placeholder.delete_prefix("Start typing e.g. ")
    expect(component).to have_css("[data-hw-combobox-name-when-new-value='manufacturer_id']")
    expect(async_src).to start_with "/search/combobox/manufacturers"
    expect(async_src).to_not include "frame_maker"
    expect(async_src).to_not include "no_manufacturer_other"
  end

  context "with frame_maker: true" do
    let(:options) { {frame_maker: true} }

    it "limits the autocomplete to frame makers" do
      expect(async_src).to include "frame_maker=true"
    end
  end

  context "with no_manufacturer_other: true" do
    let(:options) { {no_manufacturer_other: true} }

    it "renders without free text" do
      expect(async_src).to include "no_manufacturer_other=true"
      expect(component).to_not have_css("[data-hw-combobox-name-when-new-value]")
    end
  end

  context "with a form" do
    let(:bike) { Bike.new(manufacturer:, manufacturer_other:) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
    let(:manufacturer_other) { nil }
    let(:form) { BikeIndexFormBuilder.new("bike", bike, vc_test_controller.view_context, {}) }
    let(:options) { {form:} }

    it "renders the manufacturer's name and id" do
      expect(component).to have_css("input[type='hidden'][name='bike[manufacturer_id]'][value='#{manufacturer.id}']", visible: :all)
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Surly']")
    end

    context "with Manufacturer.other" do
      let(:manufacturer) { Manufacturer.other }
      let(:manufacturer_other) { "Bikes by Seth" }

      it "renders manufacturer_other, since Manufacturer.other isn't selectable" do
        expect(component).to have_css("input[type='hidden'][name='bike[manufacturer_id]'][value='Bikes by Seth']", visible: :all)
        expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Bikes by Seth']")
      end
    end
  end

  context "with forwarded options" do
    let(:options) { {name: :cmp_manufacturer_id, placeholder: "Choose"} }

    it "forwards name, but keeps its own placeholder" do
      expect(component).to have_css("input[type='hidden'][name='cmp_manufacturer_id']", visible: :all)
      expect(component).to_not have_css("input[placeholder='Choose']")
    end
  end
end
