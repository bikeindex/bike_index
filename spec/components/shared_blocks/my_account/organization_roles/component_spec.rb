# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::MyAccount::OrganizationRoles::Component, type: :component do
  let(:routes) { Rails.application.routes.url_helpers }
  let(:component) { render_inline(described_class.new(organization_roles:)) }
  let(:organization_roles) { OrganizationRole.ordered_for(user) }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:avatar) { Rack::Test::UploadedFile.new(File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
  let(:organization) { FactoryBot.create(:organization, short_name: "Bike Coop", avatar:) }
  let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user:) }

  context "with a second organization" do
    # The second organization has no avatar - the rows line up regardless
    let!(:organization_role2) { FactoryBot.create(:organization_role_claimed, user:) }

    it "renders a row for each role" do
      rows = component.css("[data-shared-blocks--my-account--organization-roles-target='item']")
      expect(rows.count).to eq 2
      expect(component).to have_link("Bike Coop", href: routes.organization_root_path(organization_id: organization.to_param))
      expect(rows.map { |row| row["data-url"] })
        .to eq([routes.my_account_organization_role_path(organization_role),
          routes.my_account_organization_role_path(organization_role2)])

      # The radios save with the form below the list, rather than sitting in a row
      expect(rows.first.css("input[name='on_by_default']").count).to eq 0
      expect(component).to have_css("input[type='radio'][name='on_by_default'][value='1'][checked]")
      expect(component).to have_css("input[type='radio'][name='on_by_default'][value='0']")

      # Both rows reserve the avatar's space, so their names line up
      expect(component).to have_css("[class~='tw:w-11'][class~='tw:shrink-0']", count: 2)
      expect(rows.first.css("img[src*='bike']").count).to eq 1
      expect(rows.last.css("img").count).to eq 0
    end
  end

  context "with only one role" do
    it "drops the ordering copy and the drag handle" do
      expect(component).to have_css("[data-shared-blocks--my-account--organization-roles-target='item']", count: 1)
      expect(component).to_not have_css("[data-shared-blocks--my-account--organization-roles-target='handle']")
      expect(component.css("h3").text.strip).to eq "Your organization role"
      expect(component.text).to_not match("Drag them into the order")
      # The organization is named, rather than "your first organization"
      expect(component.text).to match("Automatically view with Bike Coop navbar when you log in")
    end
  end

  describe "leave organization" do
    let(:leave_path) { routes.my_account_organization_role_path(organization_role) }

    it "renders the button" do
      expect(component).to have_link("Leave organization", href: leave_path)
      leave_link = component.css("a[href='#{leave_path}']").first
      expect(leave_link["data-method"]).to eq "delete"
      expect(leave_link["data-confirm"]).to match("You will have to ask an Admin from Bike Coop")
    end

    context "admin of the organization" do
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user:, role: "admin") }

      it "doesn't render the button" do
        expect(component).to_not have_css("a[href='#{leave_path}']")
      end
    end

    context "organization grants the role by email domain" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features, short_name: "Bike Coop",
          enabled_feature_slugs: ["user_role_for_user_email_domain"])
      end

      it "doesn't render the button" do
        expect(component).to_not have_css("a[href='#{leave_path}']")
      end
    end
  end
end
