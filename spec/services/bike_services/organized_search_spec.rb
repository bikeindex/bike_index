# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::OrganizedSearch, type: :service do
  describe ".email_and_name" do
    let!(:bike1) { FactoryBot.create(:bike, owner_email: "something@stuff.edu") }
    let(:user) { FactoryBot.create(:user_confirmed, name: "George Jones", email: "something2@stuff.edu") }
    let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, owner_email: user.email, user: user) }
    let!(:bike3) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: {user_name: "Sally Jones"}, owner_email: "something@stuff.com") }
    it "finds the things" do
      expect(bike2.reload.owner_name).to eq "George Jones"
      expect(bike3.reload.owner_name).to eq "Sally Jones"
      expect(described_class.email_and_name(Bike.all, "something").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, " stuff ").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, "\nstuff.EDU  ").pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(described_class.email_and_name(Bike.all, "jones").pluck(:id)).to match_array([bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, "  sally").pluck(:id)).to match_array([bike3.id])
      expect(Bike.claimed.pluck(:id)).to eq([bike2.id])
    end
  end

  describe ".location" do
    include_context :geocoder_stubbed_bounding_box
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
    let(:enabled_feature_slugs) { [] }
    let!(:bike_nyc) { FactoryBot.create(:bike, :with_address_record, address_in: :new_york) }
    let!(:bike_chicago) { FactoryBot.create(:bike, :with_address_record, address_in: :chicago) }
    let!(:stolen_nyc) { FactoryBot.create(:stolen_bike_in_nyc) }
    let!(:stolen_chicago) { FactoryBot.create(:stolen_bike_in_chicago) }
    let!(:impounded_nyc) do
      FactoryBot.create(:impound_record,
        impounded_from_address_record: FactoryBot.create(:address_record, :new_york, kind: :impounded_from)).bike
    end
    # Its coordinates are its registration address, which searching past the organization can't reach
    let!(:impounded_from_nowhere) do
      FactoryBot.create(:impound_record, bike: FactoryBot.create(:bike, :with_address_record, address_in: :new_york)).bike
    end

    it "is ignored without a locationable status" do
      expect(impounded_from_nowhere.reload.latitude).to eq bike_nyc.reload.latitude
      expect(described_class.location(Bike.all, "New York", "50", organization:)).to eq(Bike.all)
      expect(described_class.location(Bike.all, "New York", "50", organization:, search_status: "stolen").pluck(:id))
        .to match_array([stolen_nyc.id, impounded_nyc.id])
      expect(described_class.location(Bike.all, "", "50", organization:, search_status: "stolen")).to eq(Bike.all)
      expect(described_class.location(Bike.all, "Anywhere", "50", organization:, search_status: "stolen")).to eq(Bike.all)
    end

    context "with reg_address" do
      let(:enabled_feature_slugs) { %w[reg_address] }

      # Its coordinates fall back to the organization's, not a registration address
      let!(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york) }
      let!(:bike_without_address) { FactoryBot.create(:bike_organized, creation_organization: location.organization) }

      it "matches registration addresses, except searching all" do
        expect(bike_without_address.reload.latitude).to eq bike_nyc.reload.latitude
        expect(described_class.location(Bike.all, "New York", "50", organization:).pluck(:id))
          .to match_array([bike_nyc.id, stolen_nyc.id, impounded_nyc.id, impounded_from_nowhere.id])
        expect(described_class.location(Bike.all, "New York", "50", organization:, search_all: true)).to eq(Bike.all)
        expect(described_class.location(Bike.all, "New York", "50", organization:, search_all: true,
          search_status: "impounded").pluck(:id)).to match_array([stolen_nyc.id, impounded_nyc.id])
        expect(described_class.location(Bike.all, "New York", "50", organization:, search_all: true,
          search_status: "stolen_or_impounded").pluck(:id)).to match_array([stolen_nyc.id, impounded_nyc.id])
      end
    end

    context "unknown location" do
      let(:bounding_box) { [66.0, -84.22, 67.0, (0.0 / 0)] }

      it "matches nothing" do
        expect(described_class.location(Bike.all, "Nowhere", "50", organization:, search_status: "stolen").pluck(:id))
          .to eq([])
      end
    end
  end

  describe ".notes" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization) }

    before do
      FactoryBot.create(:bike_organization_note, bike: bike1, body: "has a red lock")
      FactoryBot.create(:bike_organization_note, bike: bike2, body: "parked on campus")
    end

    it "searches notes" do
      expect(described_class.notes(Bike.all, "red lock", organization).pluck(:id)).to eq([bike1.id])
      expect(described_class.notes(Bike.all, "campus", organization).pluck(:id)).to eq([bike2.id])
      expect(described_class.notes(Bike.all, "parked", organization).pluck(:id)).to eq([bike2.id])
      expect(described_class.notes(Bike.all, "nonexistent", organization).pluck(:id)).to eq([])
      expect(described_class.notes(Bike.all, "", organization)).to eq(Bike.all)
    end
  end

  describe "the settings panel's filters" do
    let(:bike_with_sticker) { FactoryBot.create(:bike, :with_address_record) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike_with_sticker) }
    let!(:bike_stolen) { FactoryBot.create(:bike, :with_stolen_record) }
    let!(:bike_impounded) { FactoryBot.create(:bike, :impounded) }

    it "narrows by each value, and leaves the search alone for any other" do
      expect(described_class.stickers(Bike.all, "with").pluck(:id)).to eq([bike_with_sticker.id])
      expect(described_class.stickers(Bike.all, "none").pluck(:id)).to match_array([bike_stolen.id, bike_impounded.id])
      expect(described_class.stickers(Bike.all, false).count).to eq 3

      expect(described_class.address(Bike.all, "with_street").pluck(:id)).to eq([bike_with_sticker.id])
      expect(described_class.address(Bike.all, "without_street").pluck(:id)).to match_array([bike_stolen.id, bike_impounded.id])
      expect(described_class.address(Bike.all, false).count).to eq 3

      expect(described_class.status(Bike.all, "stolen").pluck(:id)).to eq([bike_stolen.id])
      expect(described_class.status(Bike.all, "not_impounded").pluck(:id)).to match_array([bike_with_sticker.id, bike_stolen.id])
      expect(described_class.status(Bike.all, "stolen_or_impounded").pluck(:id)).to match_array([bike_stolen.id, bike_impounded.id])
      expect(described_class.status(Bike.all, "all").count).to eq 3

      # The panel offers street; none and with still arrive from older links
      expect(described_class.address(Bike.all, "none").to_sql).to_not eq(Bike.all.to_sql)
      expect(described_class.address(Bike.all, "with").to_sql).to_not eq(Bike.all.to_sql)

      # Each filter maps its values to scopes by hand, so a value added to the panel's table
      # without a branch here would be selectable and then quietly return every bike
      ComponentStructs::OrgSearchSettings::FILTER_GROUPS.each do |param, group|
        filter = param.to_s.delete_prefix("search_")
        next unless described_class.respond_to?(filter) # some filters scope in the controller

        group[:values].each_key do |value|
          expect(described_class.public_send(filter, Bike.all, value.to_s).to_sql)
            .to_not(eq(Bike.all.to_sql), "#{param} #{value} left the search alone")
        end
      end
    end
  end
end
