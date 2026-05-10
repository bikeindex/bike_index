require "rails_helper"

RSpec.describe OrganizedServices::MenuItems do
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  describe "for" do
    subject(:items) do
      described_class.for(organization:, current_user:,
        controller_name: "registrations", action_name: "index")
    end

    context "with a basic organization" do
      let(:organization) { FactoryBot.create(:organization) }

      it "returns a registrations link, add bike link and dividers" do
        labels = items.map { |i| i[:label] }.compact
        expect(labels).to include("#{organization.short_name} Bikes", "Add a bike")
        types = items.map { |i| i[:type] }
        expect(types).to include(:link, :divider)
      end

      it "marks the registrations link active when on the index" do
        registrations = items.find { |i| i[:label] == "#{organization.short_name} Bikes" }
        expect(registrations[:active]).to eq true
      end

      it "marks the add-a-bike link inactive when not on bikes#new" do
        add_bike = items.find { |i| i[:label] == "Add a bike" }
        expect(add_bike[:active]).to eq false
      end
    end

    context "with an ambassador organization" do
      let(:organization) { FactoryBot.create(:organization_ambassador) }

      it "returns ambassador-specific items" do
        labels = items.select { |i| i[:type] == :link }.map { |i| i[:label] }
        expect(labels).to include("#{organization.short_name} Dashboard", "Resources",
          "Getting started", "Multi search", "Discuss")
      end
    end

    context "with an organization that has impound_bikes enabled" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["impound_bikes"])
      end

      it "includes impounded bikes as a secondary link" do
        impound = items.find { |i| i[:label] == "Impounded Bikes" }
        expect(impound).to be_present
        expect(impound[:secondary]).to eq true
        expect(impound[:match_controller]).to eq true
      end
    end

    context "as a superuser" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:superuser) }

      it "appends a super_admin_link" do
        expect(items.last[:type]).to eq :super_admin_link
        expect(items.last[:label]).to eq "Super Admin for #{organization.short_name}"
      end
    end

    context "as an org admin" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

      it "includes manage_users and org_profile links" do
        labels = items.map { |i| i[:label] }
        expect(labels).to include("Manage users",
          "#{organization.short_name} profile",
          "#{organization.short_name} locations")
      end
    end

    context "with no organization" do
      it "returns an empty array" do
        expect(described_class.for(organization: nil, current_user:,
          controller_name: "x", action_name: "y")).to eq([])
      end
    end

    context "is_dropdown: true" do
      let(:organization) { FactoryBot.create(:organization) }

      it "skips the trailing divider for non-superusers" do
        dropdown = described_class.for(organization:, current_user:,
          controller_name: "x", action_name: "y", is_dropdown: true)
        non_dropdown = described_class.for(organization:, current_user:,
          controller_name: "x", action_name: "y", is_dropdown: false)
        expect(dropdown.count { |i| i[:type] == :divider }).to be < non_dropdown.count { |i| i[:type] == :divider }
      end
    end
  end
end
