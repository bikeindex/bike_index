# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddressDisplay::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {address_record:, address_hash:, visible_attribute:, render_country:} }
  let(:address_record) { nil }
  let(:address_hash) { nil }
  let(:visible_attribute) { nil }
  let(:render_country) { nil }

  it "renders" do
    expect(component).to_not have_css "span"
  end

  context "with address_record" do
    let(:address_record) { FactoryBot.build(:address_record, publicly_visible_attribute: "postal_code") }
    it "renders" do
      expect(address_record.publicly_visible_attribute).to eq "postal_code"
      expect(component).to have_content "Davis, CA 95616"
      expect(component).to_not have_content "One Shields Ave"
      expect(component).to_not have_content "C/O BicyclingPlus"
    end

    context "with visible_attribute street" do
      let(:visible_attribute) { :street }
      it "renders" do
        expect(address_record.publicly_visible_attribute).to eq "postal_code"
        expect(component).to have_content "Davis, CA 95616"
        expect(component).to have_content "One Shields Ave"
        expect(component).to have_content "C/O BicyclingPlus"
        expect(component).to have_content "One Shields Ave\nC/O BicyclingPlus\nDavis, CA 95616"
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
