# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecord::Component, type: :component do
  let(:user) { FactoryBot.create(:user) }
  let(:address_record) { AddressRecord.new(country: Country.united_states, user:) }
  let(:organization) { nil }
  let(:options) { {organization:, embed_layout:} }
  let(:embed_layout) { false }
  let(:obj) { user }

  def rendered_component(passed_obj, options)
    render_in_view_context do
      form_for passed_obj, url: "#", method: :patch, multipart: true do |f|
        f.fields_for(:address_record) do |address_form|
          # Here we provide the form_builder to the component
          render(LegacyFormWell::AddressRecord::Component.new(
            **options.merge(form_builder: address_form)
          ))
        end
      end
    end
  end

  before do
    FactoryBot.create(:state_california)
    Country.united_states
    obj.address_record = address_record
  end

  let(:component) { rendered_component(obj, options) }

  it "default preview" do
    expect(component).to have_css("label", text: "Street address")
    expect(component).to have_field("user_address_record_attributes_street")
  end

  context "with no_address: true" do
    let(:user) { FactoryBot.build(:user, no_address: true) }

    it "renders with address" do
      expect(component).to have_css("label", text: "Address")
      expect(component).not_to have_field("user_address_record_attributes_street")
    end

    context "with no_street: true" do
      let(:options) { {organization: nil, embed_layout: false, no_street: true }}
      it "renders with street_address anyway" do
        expect(component).to have_css("label", text: "Address")
        expect(component).not_to have_field("user_address_record_attributes_street")
      end
    end
  end

  context "with embed_layout: true" do
    let(:embed_layout) { true }
    it "renders with address" do
      expect(component).to have_css("label", text: "Street address")
      expect(component).to have_field("user_address_record_attributes_street")
    end
  end

  context "with organization" do
    let(:organization) { Organization.new(enabled_feature_slugs: %w[reg_address], registration_field_labels:) }
    let(:registration_field_labels) { {} }

    it "default preview" do
      expect(component).to have_css("label", text: "Street address")
      expect(component).to have_field("user_address_record_attributes_street")
    end

    context "with reg_address" do
      let(:reg_address) { "Special address label" }
      let(:registration_field_labels) { {reg_address:}.as_json }
      it "renders" do
        expect(component).to have_css("label", text: reg_address)
      end
    end

    context "with no_street" do
      let(:organization) { Organization.new(enabled_feature_slugs: %w[no_address]) }

      it "renders with address" do
        expect(organization.enabled?('no_address')).to be_truthy
        expect(component).not_to have_field("user_address_record_attributes_street")
        expect(component).to have_css("label", text: "Address")
      end
    end
  end
end
