# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::LocationAddressFields::Component, type: :component do
  let(:address_record) { AddressRecord.new(country: Country.united_states) }
  let(:options) { {default_country_id:, default_region_record_id:, default_region_string:} }
  let(:default_country_id) { nil }
  let(:default_region_record_id) { nil }
  let(:default_region_string) { nil }

  def rendered_component(address_record, options)
    render_in_view_context do
      form_for address_record, url: "#", method: :patch do |f|
        render(Org::LocationAddressFields::Component.new(**options.merge(form_builder: f)))
      end
    end
  end

  before do
    FactoryBot.create(:state_california)
    Country.united_states
  end

  let(:component) { rendered_component(address_record, options) }

  it "renders" do
    expect(component).to have_css("div")
    expect(component).to have_field("address_record_street")
    expect(component).to have_field("address_record_city")
    expect(component).to have_field("address_record_postal_code")
    expect(component).to have_select("address_record_country_id")
  end

  context "with non-US country" do
    let(:address_record) { AddressRecord.new(country: Country.canada) }

    it "renders with region text field" do
      expect(component).to have_field("address_record_region_string")
    end
  end
end
