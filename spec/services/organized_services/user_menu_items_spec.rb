require "rails_helper"

RSpec.describe OrganizedServices::UserMenuItems do
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  describe "for" do
    subject(:items) { described_class.for(organization:, current_user:) }

    define_method(:link_item) do |label, path, secondary: false, active: :auto|
      {type: :link, label:, path:, secondary:, active:}
    end

    context "with a basic organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:target) do
        [
          link_item("#{organization.short_name} Bikes", "/o/#{organization.to_param}/registrations", active: :on_registrations_index),
          {type: :disabled, label: "Incomplete registrations", secondary: true},
          link_item("Add a bike", "/o/#{organization.to_param}/bikes/new", active: :on_bikes_new),
          {type: :divider},
          {type: :disabled, label: "Registration stickers", secondary: false}
        ]
      end

      it { expect(items).to eq(target) }
    end

    context "with an ambassador organization" do
      let(:organization) { FactoryBot.create(:organization_ambassador) }
      let(:target) do
        [
          link_item("#{organization.short_name} Dashboard", "/o/#{organization.to_param}/ambassador_dashboard"),
          link_item("Resources", "/o/#{organization.to_param}/ambassador_dashboard/resources"),
          link_item("Getting started", "/o/#{organization.to_param}/ambassador_dashboard/getting_started"),
          link_item("Multi search", "/o/#{organization.to_param}/registrations/multi_search"),
          link_item("Discuss", "https://discuss.bikeindex.org")
        ]
      end

      it { expect(items).to eq(target) }
    end

    context "with impound_bikes enabled" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["impound_bikes"])
      end
      let(:target) do
        [
          link_item("#{organization.short_name} Bikes", "/o/#{organization.to_param}/registrations", active: :on_registrations_index),
          link_item("Impounded Bikes", "/o/#{organization.to_param}/impound_records", secondary: true, active: :match_controller),
          {type: :disabled, label: "Incomplete registrations", secondary: true},
          link_item("Add a bike", "/o/#{organization.to_param}/bikes/new", active: :on_bikes_new),
          {type: :divider},
          {type: :disabled, label: "Registration stickers", secondary: false}
        ]
      end

      it { expect(items).to eq(target) }
    end

    context "as a superuser" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:superuser) }
      let(:target) do
        [
          link_item("#{organization.short_name} Bikes", "/o/#{organization.to_param}/registrations", active: :on_registrations_index),
          {type: :disabled, label: "Incomplete registrations", secondary: true},
          link_item("Add a bike", "/o/#{organization.to_param}/bikes/new", active: :on_bikes_new),
          {type: :divider},
          {type: :disabled, label: "Registration stickers", secondary: false},
          link_item("Manage users", "/o/#{organization.to_param}/users", active: :match_controller),
          link_item("#{organization.short_name} profile", "/o/#{organization.to_param}/manage"),
          link_item("#{organization.short_name} locations", "/o/#{organization.to_param}/manage/locations")
        ]
      end

      it { expect(items).to eq(target) }
    end

    context "as an org admin" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
      let(:target) do
        [
          link_item("#{organization.short_name} Bikes", "/o/#{organization.to_param}/registrations", active: :on_registrations_index),
          {type: :disabled, label: "Incomplete registrations", secondary: true},
          link_item("Add a bike", "/o/#{organization.to_param}/bikes/new", active: :on_bikes_new),
          {type: :divider},
          {type: :disabled, label: "Registration stickers", secondary: false},
          link_item("Manage users", "/o/#{organization.to_param}/users", active: :match_controller),
          link_item("#{organization.short_name} profile", "/o/#{organization.to_param}/manage"),
          link_item("#{organization.short_name} locations", "/o/#{organization.to_param}/manage/locations")
        ]
      end

      it { expect(items).to eq(target) }
    end

    context "with registration_sequences enabled, as an org admin" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["registration_sequences"])
      end
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
      let(:target) do
        [
          link_item("#{organization.short_name} Bikes", "/o/#{organization.to_param}/registrations", active: :on_registrations_index),
          {type: :disabled, label: "Incomplete registrations", secondary: true},
          link_item("Add a bike", "/o/#{organization.to_param}/bikes/new", active: :on_bikes_new),
          {type: :divider},
          {type: :disabled, label: "Registration stickers", secondary: false},
          link_item("Manage users", "/o/#{organization.to_param}/users", active: :match_controller),
          link_item("Registration sequences", "/o/#{organization.to_param}/registration_sequences", active: :match_controller),
          link_item("#{organization.short_name} profile", "/o/#{organization.to_param}/manage"),
          link_item("#{organization.short_name} locations", "/o/#{organization.to_param}/manage/locations")
        ]
      end

      it { expect(items).to eq(target) }
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
      expect(labels_before).not_to include("Manage users")

      FactoryBot.create(:superuser_ability, user: current_user)
      labels_after = described_class.for(organization:, current_user: current_user.reload).map { |i| i[:label] }
      expect(labels_after).to include("Manage users")

      current_user.update(updated_at: Time.current + 1.second, skip_update: true)
      described_class.for(organization:, current_user: current_user.reload)
      expect(cache.instance_variable_get(:@data).size).to eq 4
    end
  end
end
