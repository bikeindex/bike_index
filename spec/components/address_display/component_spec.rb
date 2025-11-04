# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddressDisplay::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {address_record:, address_hash:, visible_attribute:} }
  let(:address_record) { FactoryBot.build(:address_record, publicly_visible_attribute: "postal_code") }
  let(:address_hash) { nil }
  let(:visible_attribute) { nil }

  it "renders" do
    expect(address_record.publicly_visible_attribute).to eq "postal_code"
    expect(component).to be_present
    expect(component).to have_content "95616"
    expect(component).to_not have_content "1 Shields Ave"
    expect(component).to_not have_content "C/O BicyclingPlus"
  end

  context "with visible_attribute street" do
    let(:visible_attribute) { :street }
    it "renders" do
      expect(address_record.publicly_visible_attribute).to eq "postal_code"
      expect(component).to be_present
      expect(component).to have_content "95616"
      expect(component).to have_content "1 Shields Ave"
      expect(component).to have_content "C/O BicyclingPlus"
    end
    context "with street "
  end

  context "address_hash" do
    let(:address_record) { nil }
    it "renders"

    context "legacy address_hash" do
    end
  end
end
