require "rails_helper"

RSpec.describe OrganizedServices::MenuItems do
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  describe "for" do
    subject(:items) { described_class.for(organization:, current_user:) }

    context "with a basic organization" do
      let(:organization) { FactoryBot.create(:organization) }

      it "returns canonical link items and dividers" do
        labels = items.map { |i| i[:label] }.compact
        expect(labels).to include("#{organization.short_name} Bikes", "Add a bike")
        types = items.map { |i| i[:type] }
        expect(types).to include(:link, :divider, :trailing_divider)
      end

      it "marks the registrations link with :on_registrations_index symbol (resolved at render time)" do
        registrations = items.find { |i| i[:label] == "#{organization.short_name} Bikes" }
        expect(registrations[:active]).to eq :on_registrations_index
      end

      it "marks the add-a-bike link with :on_bikes_new symbol" do
        add_bike = items.find { |i| i[:label] == "Add a bike" }
        expect(add_bike[:active]).to eq :on_bikes_new
      end

      it "always includes disabled placeholders (component decides whether to render)" do
        disabled = items.select { |i| i[:type] == :disabled }
        expect(disabled.map { |i| i[:label] }).to include("Registration stickers")
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
        expect(described_class.for(organization: nil, current_user: nil)).to eq([])
      end
    end
  end

  describe "caching" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

    around do |example|
      original = Rails.cache
      Rails.cache = cache_store
      example.run
      Rails.cache = original
    end

    it "caches the items per [organization, user]" do
      first = described_class.for(organization:, current_user:)
      second = described_class.for(organization:, current_user:)
      expect(first).to eq second
      expect(cache_store.instance_variable_get(:@data).size).to eq 1
    end

    it "produces distinct cache entries for different users" do
      other_user = FactoryBot.create(:organization_user, organization:)
      described_class.for(organization:, current_user:)
      described_class.for(organization:, current_user: other_user)
      expect(cache_store.instance_variable_get(:@data).size).to eq 2
    end

    it "busts the cache when the user becomes a superuser" do
      cached_labels = described_class.for(organization:, current_user:).map { |i| i[:label] }
      expect(cached_labels).not_to include("Super Admin for #{organization.short_name}")

      FactoryBot.create(:superuser_ability, user: current_user)
      after_labels = described_class.for(organization:, current_user: current_user.reload).map { |i| i[:label] }
      expect(after_labels).to include("Super Admin for #{organization.short_name}")
    end

    it "busts the cache when org-feature changes touch the user" do
      first = described_class.for(organization:, current_user:)
      # Simulate UpdateOrganizationAssociationsJob touching the member user
      current_user.update(updated_at: Time.current + 1.second, skip_update: true)
      second = described_class.for(organization:, current_user: current_user.reload)
      expect(cache_store.instance_variable_get(:@data).size).to eq 2
      expect(first).to eq second # same payload, but cached separately because key changed
    end
  end
end
