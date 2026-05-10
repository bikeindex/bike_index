require "rails_helper"

RSpec.describe OrganizedServices::MenuItems do
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  describe "for" do
    subject(:items) { described_class.for(organization:, current_user:) }

    context "with a basic organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:org_param) { organization.to_param }
      let(:registrations_item) do
        {type: :link, label: "#{organization.short_name} Bikes",
         path: "/o/#{org_param}/registrations", secondary: false,
         active: :on_registrations_index, match_controller: false}
      end
      let(:add_bike_item) do
        {type: :link, label: "Add a bike",
         path: "/o/#{org_param}/bikes/new", secondary: false,
         active: :on_bikes_new, match_controller: false}
      end
      let(:disabled_incomplete_registrations) do
        {type: :disabled, label: "Incomplete registrations", secondary: true}
      end
      let(:disabled_registration_stickers) do
        {type: :disabled, label: "Registration stickers", secondary: false}
      end

      it "returns the canonical link/divider/disabled items with the right active markers" do
        expect(items).to include(registrations_item, add_bike_item,
          disabled_incomplete_registrations, disabled_registration_stickers,
          {type: :divider}, {type: :trailing_divider})
      end
    end

    context "with an ambassador organization" do
      let(:organization) { FactoryBot.create(:organization_ambassador) }
      let(:org_param) { organization.to_param }
      let(:dashboard_item) do
        {type: :link, label: "#{organization.short_name} Dashboard",
         path: "/o/#{org_param}/ambassador_dashboard", secondary: false,
         active: :auto, match_controller: false}
      end

      it "returns ambassador-specific items in order" do
        labels = items.select { |i| i[:type] == :link }.map { |i| i[:label] }
        expect(labels).to eq(["#{organization.short_name} Dashboard", "Resources",
          "Getting started", "Multi search", "Discuss"])
        expect(items).to include(dashboard_item)
      end
    end

    context "with impound_bikes enabled" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["impound_bikes"])
      end
      let(:impound_item) do
        {type: :link, label: "Impounded Bikes",
         path: "/o/#{organization.to_param}/impound_records", secondary: true,
         active: :auto, match_controller: true}
      end

      it "includes impounded bikes as a secondary, controller-matched link" do
        expect(items).to include(impound_item)
      end
    end

    context "as a superuser" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:superuser) }
      let(:super_admin_item) do
        {type: :super_admin_link,
         label: "Super Admin for #{organization.short_name}",
         path: "/admin/organizations/#{organization.to_param}"}
      end

      it "appends a super_admin_link as the last item" do
        expect(items.last).to eq super_admin_item
      end
    end

    context "as an org admin" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

      it "includes manage_users, profile, and locations links" do
        labels = items.map { |i| i[:label] }
        expect(labels).to include("Manage users",
          "#{organization.short_name} profile",
          "#{organization.short_name} locations")
      end
    end

    context "with no organization" do
      it "returns an empty array" do
        expect(described_class.for(organization: nil, current_user: nil)).to eq([])
      end
    end
  end

  describe "caching", :caching do
    include_context :caching_basic

    let(:organization) { FactoryBot.create(:organization) }

    it "memoizes per [organization, user], busts on user touch and superuser ability create" do
      first = described_class.for(organization:, current_user:)
      second = described_class.for(organization:, current_user:)
      expect(first).to eq second
      expect(cache.instance_variable_get(:@data).size).to eq 1

      other_user = FactoryBot.create(:organization_user, organization:)
      described_class.for(organization:, current_user: other_user)
      expect(cache.instance_variable_get(:@data).size).to eq 2

      labels_before = described_class.for(organization:, current_user:).map { |i| i[:label] }
      expect(labels_before).not_to include("Super Admin for #{organization.short_name}")

      FactoryBot.create(:superuser_ability, user: current_user)
      labels_after = described_class.for(organization:, current_user: current_user.reload).map { |i| i[:label] }
      expect(labels_after).to include("Super Admin for #{organization.short_name}")

      current_user.update(updated_at: Time.current + 1.second, skip_update: true)
      described_class.for(organization:, current_user: current_user.reload)
      expect(cache.instance_variable_get(:@data).size).to eq 4
    end
  end
end
