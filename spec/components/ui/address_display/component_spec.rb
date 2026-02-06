# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::AddressDisplay::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {address_record:, address_hash:, visible_attribute:, render_country:, kind:} }
  let(:address_record) { nil }
  let(:address_hash) { nil }
  let(:visible_attribute) { nil }
  let(:render_country) { nil }
  let(:kind) { nil }

  it "renders" do
    expect(component).to_not have_css "span"
  end

  context "with address_record" do
    let(:address_record) { FactoryBot.build(:address_record, publicly_visible_attribute: "postal_code", street_2: "C/O BicyclingPlus") }
    it "renders with region_record" do
      expect(address_record.region_record).to be_present
      expect(address_record.region).to eq "CA"
      expect(address_record.publicly_visible_attribute).to eq "postal_code"
      expect(component).to have_content "Davis, CA 95616"
      expect(component).to_not have_content "One Shields Ave"
      expect(component).to_not have_content "C/O BicyclingPlus"

      component_text = whitespace_normalized_body_text(component.to_html)
      expect(component_text).to eq address_record.formatted_address_string
    end

    context "with visible_attribute street" do
      let(:visible_attribute) { :street }
      it "renders multiline by default" do
        expect(address_record.publicly_visible_attribute).to eq "postal_code"
        expect(component).to have_content "Davis, CA 95616"
        expect(component).to have_content "One Shields Ave"
        expect(component).to have_content "C/O BicyclingPlus"
        expect(component).to have_content "One Shields Ave\nC/O BicyclingPlus\nDavis, CA 95616"
        expect(component).to have_css("span.tw\\:block", count: 3)

        # Component display doesn't put a comma between everything that formatted_address_string does, so drop commas
        component_text = whitespace_normalized_body_text(component.to_html).tr(",", "")
        expect(component_text).to eq address_record.formatted_address_string(visible_attribute: :street).tr(",", "")
      end

      context "with kind: :single_line" do
        let(:kind) { :single_line }
        it "renders on single line" do
          expect(component).to have_content "One Shields Ave, C/O BicyclingPlus, Davis, CA 95616"
          expect(component).not_to have_css("span.tw\\:block")

          component_text = whitespace_normalized_body_text(component.to_html)
          expect(component_text).to eq address_record.formatted_address_string(visible_attribute: :street)
        end
      end

      context "with persisted address_record" do
        let(:address_record) { FactoryBot.create(:address_record, :chicago, street_2: nil) }
        it "renders with region abbreviation" do
          expect(address_record.reload.region_record).to be_present
          expect(address_record.region_record.abbreviation).to eq "IL"
          expect(address_record.region).to eq "IL"
          expect(component).to have_content "1300 W 14th Pl"
          expect(component).to have_content "Chicago, IL 60608"

          component_text = whitespace_normalized_body_text(component.to_html).tr(",", "")
          expect(component_text).to eq address_record.formatted_address_string(visible_attribute: :street).tr(",", "")
        end
      end
    end

    context "with visible_attribute city" do
      let(:visible_attribute) { :city }
      it "renders" do
        expect(component).to have_content "Davis"
        expect(component).to_not have_content "95616"
        expect(component).to_not have_content "One Shields Ave"
        expect(component).to_not have_content "C/O BicyclingPlus"
        expect(component).to_not have_content "United States"

        component_text = whitespace_normalized_body_text(component.to_html)
        expect(component_text).to eq address_record.formatted_address_string(visible_attribute: :city)
      end
      context "with render_country" do
        let(:render_country) { true }
        it "renders" do
          expect(component).to have_content "Davis, CA, United States"
          expect(component).to_not have_content "95616"
          expect(component).to_not have_content "One Shields Ave"
          expect(component).to_not have_content "C/O BicyclingPlus"
        end
      end
    end
  end

  context "address_hash" do
    let(:address_record) { nil }
    let(:address_hash) do
      {street: "Some Ave", city: "Brooklyn", zipcode: "11222",
       latitude: 40, longitude: -73, state: "NY", country: "US"}
    end
    it "renders" do
      expect(component).to have_content "Brooklyn, NY 11222"
      expect(component).to_not have_content "Some Ave"
    end

    context "with visible_attribute street" do
      let(:visible_attribute) { :street }
      it "renders" do
        expect(component).to have_content "Brooklyn, NY 11222"
        expect(component).to have_content "Some Ave"
        expect(component).to have_content "Some Ave\nBrooklyn, NY 11222"
      end

      context "with street with comma" do
        let(:address_hash) do
          {street: "One Shields Ave, C/O BicyclingPlus", city: "Davis", zipcode: "95616",
           latitude: 40, longitude: -73, state: "CA", country: "US"}.as_json
        end
        it "splits street" do
          expect(component).to have_content "Davis, CA 95616"
          expect(component).to have_content "One Shields Ave"
          expect(component).to have_content "C/O BicyclingPlus"
          expect(component).to have_content "One Shields Ave\nC/O BicyclingPlus\nDavis, CA 95616"
        end
      end
    end
  end
end
