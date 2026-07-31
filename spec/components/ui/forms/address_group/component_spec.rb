# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddressGroup::Component, type: :component do
  let(:address_record) { AddressRecord.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:address_record, address_record, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(form_builder:, **options)) }

  it "renders the address fields with a default street label" do
    expect(component).to have_css("input[name='address_record[street]']")
    expect(component).to have_css("input[name='address_record[city]']")
    expect(component).to have_css("select[name='address_record[region_record_id]']")
    expect(component).to have_css("input[name='address_record[region_string]']")
    expect(component).to have_css("input[name='address_record[postal_code]']")
    expect(component).to have_css("select[name='address_record[country_id]']")
    expect(component).to have_css("label", text: "Address")
    expect(component).to have_no_css("input[name='address_record[street_2]']")
    expect(component).to have_no_css("[required]")
  end

  context "with street_2" do
    let(:options) { {street_2: true} }

    it "renders the street_2 field" do
      expect(component).to have_css("input[name='address_record[street_2]']")
      expect(component).to have_css("label", text: "Address line 2")
    end
  end

  context "with required" do
    let(:options) { {required: true, street_2: true} }

    it "requires every field but street_2" do
      expect(component).to have_css("input[name='address_record[street]'][required]")
      expect(component).to have_css("input[name='address_record[city]'][required]")
      expect(component).to have_css("select[name='address_record[region_record_id]'][required]")
      expect(component).to have_css("input[name='address_record[postal_code]'][required]")
      expect(component).to have_css("select[name='address_record[country_id]'][required]")
      expect(component).to have_css("input[name='address_record[street_2]']:not([required])")
      # The hidden region_string is left optional - the browser can't report validity on it
      expect(component).to have_css("input[name='address_record[region_string]']:not([required])")
    end

    context "with a non-US country" do
      let!(:country) { FactoryBot.create(:country, name: "Testland") }
      let(:address_record) { AddressRecord.new(country_id: country.id) }

      it "moves required to region_string" do
        expect(component).to have_css("input[name='address_record[region_string]'][required]")
        expect(component).to have_css("select[name='address_record[region_record_id]']:not([required])")
      end
    end
  end

  context "with a street_label" do
    let(:options) { {street_label: "Address or intersection"} }

    it "uses the custom street label" do
      expect(component).to have_css("label", text: "Address or intersection")
    end
  end

  context "with a default_country_id" do
    let!(:country) { FactoryBot.create(:country, name: "Testland") }
    let(:options) { {default_country_id: country.id} }

    it "preselects the default country" do
      expect(component).to have_css("select[name='address_record[country_id]'] option[value='#{country.id}'][selected]")
    end

    context "when the object already has a country" do
      let(:other_country) { FactoryBot.create(:country, name: "Otherland") }
      let(:address_record) { AddressRecord.new(country_id: other_country.id) }

      it "keeps the object's country over the default" do
        expect(component).to have_css("select[name='address_record[country_id]'] option[value='#{other_country.id}'][selected]")
        expect(component).to have_no_css("option[value='#{country.id}'][selected]")
      end
    end
  end
end
