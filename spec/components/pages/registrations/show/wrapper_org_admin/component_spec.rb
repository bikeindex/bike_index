# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::WrapperOrgAdmin::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["registration_notes"]) }
  let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }

  # The wrapper folds this into its cache key, so these still expire the cached panel
  describe "#cache_version" do
    def cache_version
      described_class.new(bike: bike.reload, current_user:, organization:, org_role: :staff).cache_version
    end

    it "changes when an organization note is added" do
      expect { BikeOrganizationNote.upsert(bike:, organization:, body: "hi", user: current_user) }
        .to change { cache_version }
    end

    it "changes when the owner registers another bike" do
      expect { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, user: bike.user) }
        .to change { cache_version }
    end
  end

  describe "other registrations" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[additional_registrations_information]) }

    context "with another registration" do
      let!(:other_bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, user: bike.user) }

      it "renders the column-toggle settings inside the card" do
        render_inline(described_class.new(bike: bike.reload, current_user:, organization:, org_role: :staff))

        expect(page).to have_css("[data-controller~='org--search-column-toggle']")
        expect(page).to have_text("Visible columns")
        expect(page).to have_button("settings", visible: :all)
      end

      context "on a bike registered elsewhere, viewed by a limited member" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

        it "renders the card" do
          render_inline(described_class.new(bike: bike.reload, current_user:, organization:, org_role: :limited))

          expect(page).to have_text("Other registrations by this user")
          expect(page).to have_text("1 other registrations")
        end
      end
    end

    it "renders the card when the owner has no other registrations" do
      render_inline(described_class.new(bike: bike.reload, current_user:, organization:, org_role: :staff))

      expect(page).to have_text("Other registrations by this user")
      expect(page).to have_text("None found")
    end
  end
end
