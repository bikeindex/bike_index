# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserServices::MenuItemsAccount do
  let(:user) { FactoryBot.create(:user_confirmed) }

  describe "for" do
    let(:items) { described_class.for(user:, **options) }
    let(:options) { {} }
    let(:labels) { items.map { |item| item[:label] } }

    it "leads with the account rows, logout last" do
      expect(labels).to eq(["Your registrations", "Register a new bike", "#{user.email} settings",
        nil, "Log out"])
      expect(items.map { |item| item[:type] }).to eq(%i[link link link divider link])
    end

    it "sends the registration row into the flow, covering every step of it" do
      registration = items.find { |item| item[:label] == "Register a new bike" }

      expect(registration[:path]).to eq "/register"
      expect(registration[:match_paths]).to eq "/register/**"
    end

    # Each menu tints it for itself, so the row only says which one it is
    it "marks logout danger, and nothing else" do
      expect(items.select { |item| item[:danger] }.map { |item| item[:label] }).to eq(["Log out"])
    end

    # navUserSettingLink is how the signed-in email is read off a page
    it "carries the email on the settings row" do
      settings = items.find { |item| item[:id] == "navUserSettingLink" }

      expect(settings[:label]).to eq "#{user.email} settings"
      expect(settings[:data]).to eq({email: user.email})
    end

    # The sidebar's menu unrolls upward off the account block, so it reads the other way
    context "opens: :up" do
      let(:options) { {opens: :up} }

      it "leads with logout, the account rows reversed" do
        expect(labels).to eq(["Log out", nil, "#{user.email} settings", "Register a new bike",
          "Your registrations"])
      end
    end

    context "with an organization" do
      let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:) }

      # Its own section, set off on both sides, and it holds its order whichever way the
      # rest of the menu runs
      it "sets the switcher off between the account rows and logout" do
        expect(labels).to eq(["Your registrations", "Register a new bike", "#{user.email} settings",
          nil, "Viewing without any organization", "Switch to Brakebills", nil, "Log out"])
      end

      context "opens: :up" do
        let(:options) { {opens: :up} }

        it "keeps the switcher's own order" do
          expect(labels).to eq(["Log out", nil, "Viewing without any organization",
            "Switch to Brakebills", nil, "#{user.email} settings", "Register a new bike",
            "Your registrations"])
        end
      end
    end
  end

  describe "the organization switcher" do
    let(:items) { described_class.for(user:, **options) }
    let(:options) { {} }
    let(:switcher) { items.select { |item| item[:label].to_s.match?(/organization|Brakebills|Physical Kids/) } }

    it "is absent for a user in no organization" do
      expect(switcher).to eq([])
    end

    # A superuser reaches an organization without being a member of it
    context "viewing an organization they're no member of" do
      let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
      let(:options) { {current_organization: organization} }

      it "carries the row for it, and the one out of it" do
        expect(switcher)
          .to eq([{type: :link, label: "View without any organization",
                   path: "http://test.host/?organization_id=false",
                   icon: nil,
                   data: {controller: "page-block--navbar-switch-no-organization"}},
            {type: :disabled, label: "Viewing Brakebills"}])
      end
    end

    context "with one organization" do
      let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:) }

      # The shape is UserServices::MenuItemsOrg's, so one renderer takes either list
      it "leads with the no-organization row, which is where they already are" do
        expect(switcher)
          .to eq([{type: :disabled, label: "Viewing without any organization"},
            {type: :link, label: "Switch to Brakebills", path: "/o/#{organization.to_param}",
             icon: nil}])
      end

      # Whichever they're on has nowhere to go, so the label moves with them
      context "viewing it" do
        let(:options) { {current_organization: organization} }

        it "labels the one they're viewing, and links back out of it" do
          expect(switcher.first[:label]).to eq "View without any organization"
          expect(switcher.first[:path]).to match(/organization_id=false\z/)
          expect(switcher.last).to eq({type: :disabled, label: "Viewing Brakebills"})
        end
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
      it "takes the oldest memberships, in order" do
        expect(switcher.drop(1).map { |item| item[:label] })
          .to eq(organizations.first(described_class::SWITCHER_ORGANIZATIONS)
            .map { |organization| "Switch to #{organization.name}" })
      end
    end
  end

  describe "opens" do
    it "raises on a direction it can't order by" do
      expect {
        described_class.for(user:, opens: :upward)
      }.to raise_error(ArgumentError, /opens/)
    end
  end

  describe "marketplace messages" do
    let(:items) { described_class.for(user:) }

    it "is absent for a user with none" do
      expect(items.map { |item| item[:label] }).to_not include("Marketplace messages")
    end

    context "with a message" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
      let!(:marketplace_message) do
        FactoryBot.create(:marketplace_message, marketplace_listing:, sender: user)
      end

      # Second, among the account rows -- the messages sit with the registrations they're about
      it "links to the messages" do
        expect(items[1]).to eq({type: :link, label: "Marketplace messages",
                                path: "/my_account/messages", icon: nil})
      end
    end
  end
end
