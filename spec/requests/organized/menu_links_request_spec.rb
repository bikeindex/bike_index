require "rails_helper"

# Every row the menu offers has to land on the page it names, for whoever it's offered to
RSpec.describe "UserServices::MenuItemsOrg links", type: :request do
  let(:current_organization) { FactoryBot.create(:organization_brakebills, :in_nyc, :with_auto_user) }
  let(:link_paths) do
    UserServices::MenuItemsOrg.for(organization: current_organization.reload, current_user:)
      .flat_map { |item| item[:children] || [item] }
      .filter_map { |item| item[:path] if item[:type] == :link }
  end

  before { log_in(current_user) }

  shared_examples "every link opens" do
    it "responds without redirecting" do
      expect(link_paths.count).to be > 10

      statuses = link_paths.to_h do |path|
        get path
        [path, response.status]
      end

      expect(statuses.reject { |_path, status| status == 200 }).to eq({})
    end
  end

  context "as a member" do
    let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization) }

    include_examples "every link opens"
  end

  context "as an admin" do
    let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }

    include_examples "every link opens"
  end
end
