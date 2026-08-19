# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserServices::MenuItemsAccount do
  let(:user) { FactoryBot.create(:user_confirmed) }

  describe "organization_switcher" do
    it "is empty for a user in no organization" do
      expect(described_class.organization_switcher(user)).to eq([])
    end

    context "with one organization" do
      let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:) }

      # The shape is UserServices::MenuItemsOrg's, so one renderer takes either list
      it "leads with the no-organization row, which is where they already are" do
        expect(described_class.organization_switcher(user))
          .to eq([{type: :disabled, label: "Viewing without any organization"},
            {type: :link, label: "View in Brakebills", path: "/o/#{organization.to_param}",
             icon: nil, match: :path, matching_controllers: []},
            {type: :divider}])
      end

      # Whichever they're on has nowhere to go, so the label moves with them
      it "labels the one they're viewing, and links back out of it" do
        items = described_class.organization_switcher(user, current_organization: organization)

        expect(items.first[:label]).to eq "View without any organization"
        expect(items.first[:path]).to match(/organization_id=false\z/)
        expect(items[1]).to eq({type: :disabled, label: "Viewing in Brakebills"})
        expect(items.last).to eq({type: :divider})
      end
    end

    context "with more organizations than it shows" do
      let!(:organizations) do
        (1..described_class::SWITCHER_ORGANIZATIONS + 2).map do |i|
          organization = FactoryBot.create(:organization, name: "Physical Kids #{i}")
          FactoryBot.create(:organization_role_claimed, user:, organization:)
          organization
        end
      end

      # A reader in dozens of them would otherwise push logout off the menu
      it "takes the oldest memberships, in order, and still leaves the divider" do
        items = described_class.organization_switcher(user)

        expect(items.last).to eq({type: :divider})
        expect(items[1...-1].map { |item| item[:label] })
          .to eq(organizations.first(described_class::SWITCHER_ORGANIZATIONS)
            .map { |organization| "View in #{organization.name}" })
      end
    end
  end

  describe "marketplace_messages" do
    it "is nil for a user with none" do
      expect(described_class.marketplace_messages(user)).to be_nil
    end

    context "with a message" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
      let!(:marketplace_message) do
        FactoryBot.create(:marketplace_message, marketplace_listing:, sender: user)
      end

      it "links to the messages" do
        expect(described_class.marketplace_messages(user))
          .to eq({type: :link, label: "Marketplace messages", path: "/my_account/messages",
                  icon: nil, match: :path, matching_controllers: []})
      end
    end
  end
end
