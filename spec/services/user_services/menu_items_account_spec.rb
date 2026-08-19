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

      it "labels the row for the organization's admin, above a divider" do
        expect(described_class.organization_switcher(user))
          .to eq([{label: "Switch to Brakebills admin", path: "/o/#{organization.to_param}"},
            {type: :divider}])
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
        expect(items[0...-1].map { |item| item[:label] })
          .to eq(organizations.first(described_class::SWITCHER_ORGANIZATIONS)
            .map { |organization| "Switch to #{organization.name} admin" })
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
          .to eq({label: "Marketplace messages", path: "/my_account/messages"})
      end
    end
  end
end
