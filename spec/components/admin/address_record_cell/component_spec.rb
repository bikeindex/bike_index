# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AddressRecordCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {address_record:} }

  context "with city and region_string" do
    let(:address_record) do
      AddressRecord.new(
        city: "Portland",
        region_string: "OR",
        country: Country.united_states
      )
    end

    it "renders city and region" do
      expect(component.text).to match(/Portland/)
      expect(component.text).to match(/OR/)
    end
  end

  context "with city and non-US country (no region)" do
    let(:address_record) do
      AddressRecord.new(
        city: "Vancouver",
        country: Country.friendly_find("CA")
      )
    end

    it "renders city and country abbreviation" do
      expect(component.text).to match(/Vancouver/)
      expect(component.text).to match(/CA/)
    end
  end

  context "with city and non-US country with region" do
    let(:address_record) do
      AddressRecord.new(
        city: "Toronto",
        region_string: "ON",
        country: Country.friendly_find("CA")
      )
    end

    it "renders city and region (not country)" do
      expect(component.text).to match(/Toronto/)
      expect(component.text).to match(/ON/)
      expect(component.text).not_to match(/CA/)
    end
  end

  context "with only city" do
    let(:address_record) { AddressRecord.new(city: "Portland") }

    it "renders city only" do
      expect(component.text).to match(/Portland/)
    end
  end
end
