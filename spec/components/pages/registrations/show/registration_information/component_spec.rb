# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::RegistrationInformation::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[registration_sequences]) }
  let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
  let(:org_role) { :staff }
  let(:component) { described_class.new(bike: bike.reload, organization:, org_role:) }

  describe "registration sequence" do
    def acknowledgment_value = page.find("dt", text: "Registration sequence").sibling("dd")

    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, propulsion_type: "pedal-assist") }

    it "renders a blank row without an acknowledgment" do
      render_inline(component)

      expect(acknowledgment_value.text.strip).to eq "-"
    end

    context "with an acknowledgment" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }
      let!(:acknowledgment) { FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike:) }

      it "renders when it was acknowledged" do
        render_inline(component)

        expect(acknowledgment_value).to have_text("Acknowledged")
        expect(acknowledgment_value).to have_css(".localizeTime.withPreposition")
      end

      context "to another organization's sequence" do
        let(:registration_sequence) { FactoryBot.create(:registration_sequence_active) }

        it "doesn't render it" do
          render_inline(component)

          expect(acknowledgment_value.text.strip).to eq "-"
        end
      end
    end

    context "on a bike that isn't an e-vehicle" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, propulsion_type: "foot-pedal") }

      it "doesn't render the row" do
        render_inline(component)

        expect(page).to have_no_text("Registration sequence")
      end
    end

    context "without the registration_sequences feature" do
      let(:organization) { FactoryBot.create(:organization) }

      it "doesn't render the row" do
        render_inline(component)

        expect(page).to have_no_text("Registration sequence")
      end
    end
  end

  describe "e-vehicle audit" do
    it "doesn't render the row for a bike that isn't an e-vehicle" do
      render_inline(component)

      expect(page).to have_no_text("E-Vehicle Audit")
    end

    context "on an e-vehicle" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, propulsion_type: "pedal-assist") }

      it "renders that it isn't audited" do
        render_inline(component)

        expect(page).to have_text("Not audited")
      end
    end
  end

  context "on a bike registered elsewhere, without credibility or sticker features" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

    it "renders that nothing is visible" do
      render_inline(component)

      expect(page).to have_text("No registration information visible to #{organization.short_name}")
    end
  end

  describe "ComponentPreview" do
    let!(:organization) { FactoryBot.create(:organization_brakebills) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
    let!(:other_bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

    it "renders a situation the environment has no record for" do
      render_preview(:staff_with_acknowledgment)

      expect(page).to have_text("Nothing to preview")
    end

    it "renders a situation with its record" do
      render_preview(:organization_without_features)

      expect(page).to have_text("No registration information visible to Preview")
    end
  end
end
