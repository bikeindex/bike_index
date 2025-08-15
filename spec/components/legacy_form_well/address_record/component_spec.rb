# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecord::Component, type: :component do
  let(:user) { FactoryBot.create(:user) }
  let(:address_record) { AddressRecord.new(country: Country.united_states) }
  let(:organization) { nil }
  let(:options) { {form_builder:, organization:, no_street: user.no_address?} }

  def rendered_component(passed_user, passed_organization = nil)
    render_in_view_context do
      form_for passed_user, url: "/my_account", method: :patch, multipart: true do |f|
        f.fields_for(:address_record) do |address_form|
          # Here we provide the form_builder to the component
          render(LegacyFormWell::AddressRecord::Component.new(
            form_builder: address_form,
            organization: passed_organization,
            no_street: passed_user.no_address?
          ))
        end
      end
    end
  end

  before do
    FactoryBot.create(:state_california)
    Country.united_states
    user.address_record = address_record
  end

  let(:component) { rendered_component(user, organization) }

  it "default preview" do
    expect(component).to have_css("label", text: "Street address")
  end

  context "with no_address: true" do
    let(:user) { FactoryBot.create(:user, no_address: true) }
    it "renders with address" do
      expect(component).to have_css("label", text: "Address")
    end
  end

  context "with organization" do
    let(:organization) { Organization.new(enabled_feature_slugs: %w[reg_address], registration_field_labels:) }
    let(:registration_field_labels) { {} }

    it "default preview" do
      component = rendered_component(user)

      expect(component).to have_css("label", text: "Street address")
    end

    context "with reg_address" do
      let(:reg_address) { "Special address label" }
      let(:registration_field_labels) { {reg_address:}.as_json }
      it "renders" do
        expect(component).to have_css("label", text: reg_address)
      end
    end
  end
end
