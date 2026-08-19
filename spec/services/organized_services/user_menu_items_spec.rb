require "rails_helper"

RSpec.describe OrganizedServices::UserMenuItems do
  let(:current_user) { FactoryBot.create(:organization_user, organization:) }

  describe "for" do
    subject(:items) { described_class.for(organization:, current_user:) }

    define_method(:link_item) do |label, path, icon: nil, match: :path, matching_controllers: []|
      {type: :link, label:, path:, icon:, match:, matching_controllers:}
    end

    define_method(:group_item) do |key, label, icon, children|
      {type: :group, key:, label:, icon:, children:}
    end

    context "with no organization" do
      let(:organization) { nil }
      let(:current_user) { FactoryBot.create(:user_confirmed) }

      it { expect(items).to eq([]) }
    end

    context "with no user" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { nil }

      it { expect(items).to eq([]) }
    end

    # Every standard row is a controller Organized::BaseController redirects an
    # ambassador organization away from, so none of them belong in its menu
    context "with an ambassador organization" do
      let(:organization) { FactoryBot.create(:organization_ambassador, short_name: "Fillory") }
      let(:slug) { organization.to_param }

      it "renders the ambassador's own rows instead of the standard ones" do
        expect(items).to eq([
          link_item("Fillory Dashboard", "/o/#{slug}/ambassador_dashboard", icon: "bar-chart"),
          link_item("Resources", "/o/#{slug}/ambassador_dashboard/resources", icon: "list"),
          link_item("Getting started", "/o/#{slug}/ambassador_dashboard/getting_started",
            icon: "graduation-cap"),
          link_item("Multi search", "/o/#{slug}/registrations/multi_search", icon: "searcher"),
          link_item("Discuss", "https://discuss.bikeindex.org", icon: "chat")
        ])
      end
    end

    context "with a basic organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:target) do
        [
          group_item(:registrations, "#{organization.short_name} Registrations", "bike", [
            link_item("Search Registrations", "/o/#{organization.to_param}/registrations",
              match: :controller_action)
          ]),
          link_item("Add a bike", "/o/#{organization.to_param}/registrations/new",
            icon: "plus-circle", match: :full_path)
        ]
      end

      it "drops every group whose features are off, and the divider left behind" do
        expect(items).to eq(target)
      end

      context "gone back to the old view" do
        subject(:items) { described_class.for(organization:, current_user:, old_register_view: true) }

        it "points add a bike at the embed form" do
          expect(items.last).to eq(link_item("Add a bike", "/o/#{organization.to_param}/bikes/new",
            icon: "plus-circle", match: :full_path))
        end
      end
    end

    context "with every feature, for an admin" do
      let(:organization) { FactoryBot.create(:organization_brakebills) }
      let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
      let(:slug) { organization.to_param }

      it "groups the menu the way the design lays it out" do
        expect(items.map { |item| item[:type] }).to eq(%i[group link divider group group group link
          link link link link divider group])

        groups = items.select { |item| item[:type] == :group }
        expect(groups.map { |group| group[:key] }).to eq(%i[registrations impounded parking bulk settings])
        expect(groups.map { |group| group[:icon] })
          .to eq(%w[bike impound map-pin import-export gear])
      end

      it "fills the registrations group with the design's five children" do
        registrations = items.find { |item| item[:key] == :registrations }

        expect(registrations[:label]).to eq "Brakebills Registrations"
        expect(registrations[:children]).to eq([
          link_item("Search Registrations", "/o/#{slug}/registrations", match: :controller_action),
          link_item("Incomplete registrations", "/o/#{slug}/bikes/incompletes"),
          link_item("Multi search", "/o/#{slug}/registrations/multi_search"),
          link_item("Recoveries", "/o/#{slug}/bikes/recoveries"),
          link_item("Registration stickers", "/o/#{slug}/stickers", match: :controller)
        ])
      end

      it "renders the one row with nowhere to link as disabled" do
        impounded = items.find { |item| item[:key] == :impounded }

        expect(impounded[:children].last).to eq({type: :disabled, label: "Add an Impounded Vehicle"})
        expect(items.select { |item| item[:type] == :disabled }).to eq([])
      end

      it "points reports at the overview dashboard" do
        expect(items.find { |item| item[:label] == "Reports" })
          .to eq(link_item("Reports", "/o/#{slug}/dashboard", icon: "bar-chart", match: :controller))
      end

      # Managing impounding is the settings group's, so this one is only the vehicles
      it "keeps configuration out of the impounded group" do
        impounded = items.find { |item| item[:key] == :impounded }

        expect(impounded[:children].map { |child| child[:label] })
          .to eq(["Search Impounded Vehicles", "Impounded claims", "Add an Impounded Vehicle"])
      end

      it "points messaging at the custom emails index, rather than at a single email" do
        expect(items.find { |item| item[:label] == "Messaging" })
          .to eq(link_item("Messaging", "/o/#{slug}/emails", icon: "chat", match: :controller))
        expect(organization.enabled?("organization_stolen_message")).to be true
        expect(items.map { |item| item[:label] }).to_not include("Stolen Message")
      end

      it "puts every organization-admin page under settings" do
        settings = items.find { |item| item[:key] == :settings }

        expect(settings[:label]).to eq "Brakebills Settings"
        expect(settings[:children]).to eq([
          link_item("Brakebills profile", "/o/#{slug}/manage"),
          link_item("Brakebills locations", "/o/#{slug}/manage/locations"),
          link_item("Manage users", "/o/#{slug}/users", match: :controller),
          link_item("Impounding", "/o/#{slug}/manage_impounding/edit"),
          link_item("Stolen Bike Hot Sheet", "/o/#{slug}/hot_sheet/edit"),
          link_item("Registration sequences", "/o/#{slug}/registration_sequences",
            match: :controller, matching_controllers: ["organized/registration_sequence_pages"])
        ])
      end
    end

    context "with every feature, for a member" do
      let(:organization) { FactoryBot.create(:organization_brakebills) }

      it "drops the settings group and messaging" do
        expect(items.map { |item| item[:key] }.compact).to eq(%i[registrations impounded parking bulk])
        expect(items.map { |item| item[:label] }).to_not include("Messaging")
      end
    end

    # Its edit page is the only way in, so without it the feature is unreachable
    context "with organization_stolen_message but not customize_emails" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["organization_stolen_message"])
      end
      let(:stolen_message) do
        link_item("Stolen Message", "/o/#{organization.to_param}/emails/organization_stolen_message/edit",
          icon: "chat")
      end

      context "for an admin" do
        let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

        it "stands the stolen message in for messaging" do
          expect(items).to include(stolen_message)
        end
      end

      it "drops it for a member, who can't edit it" do
        expect(items).to_not include(stolen_message)
      end
    end

    context "with a lightspeed organization" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["csv_exports"], pos_kind: :lightspeed_pos)
      end

      it "adds the integration panel as a row of its own, keyed by id" do
        expect(items.find { |item| item[:icon] == "lightspeed" })
          .to eq(link_item("Lightspeed Integration Panel",
            "/lightspeed_interface?organization_id=#{organization.id}", icon: "lightspeed"))
      end
    end

    context "with an ascend organization" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["csv_exports"], pos_kind: :ascend_pos)
      end

      it "labels the import Ascend" do
        bulk = items.find { |item| item[:key] == :bulk }

        expect(bulk[:children].map { |child| child[:label] }).to eq(["Ascend Imports", "Exports"])
      end
    end
  end
end
