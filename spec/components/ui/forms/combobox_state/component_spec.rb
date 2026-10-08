# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::ComboboxState::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {} }

  it "renders a state combobox showing and submitting the abbreviation, with a select without JavaScript" do
    expect(component).to have_css("input[type='hidden'][name='state']", visible: :all)
      .and have_css("[role='option'][data-value='CO']", text: "Colorado", visible: :all)
      .and have_css("noscript", visible: :all)
    expect(component).to have_css("[role='option'][data-value='CO'] .tw\\:text-gray-500", text: "(CO)", visible: :all)
    expect(component.css("noscript").to_html).to include("<option value=\"CO\">Colorado (CO)</option>")
  end

  context "with states and a value" do
    let(:options) { {states: [{name: "Colorado", abbr: "CO"}, {name: "Texas", abbr: "TX"}], html_options: {value: "TX"}} }

    it "offers only those states, showing the chosen one" do
      expect(component).to have_css("[role='option']", count: 2, visible: :all)
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Texas (TX)']")
      expect(component.css("input[type='hidden'][name='state']").first["value"]).to eq "TX"
    end
  end

  context "with ids, on a form" do
    let(:california) { FactoryBot.create(:state_california) }
    let(:address_record) { AddressRecord.new(region_record_id: california.id) }
    let(:form) do
      BikeIndexFormBuilder.new(:address_record, address_record, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
    end
    let(:options) { {name: :region_record_id, ids: true, html_options: {form:}} }

    it "submits the State record's id, showing the form object's" do
      expect(component).to have_css("[role='option'][data-value='#{california.id}']", text: "California (CA)", visible: :all)
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='California (CA)']")
      expect(component.css("input[type='hidden'][name='address_record[region_record_id]']").first["value"]).to eq california.id.to_s
    end
  end
end
