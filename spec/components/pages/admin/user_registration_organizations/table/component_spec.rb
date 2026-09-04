# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::UserRegistrationOrganizations::Table::Component, type: :component do
  let(:component) do
    with_request_url("/admin/user_registration_organizations") do
      render_inline(described_class.new(user_registration_organizations: [user_registration_organization],
        sort_state: ComponentStructs::SortState.new(search_params: {period: "all"})))
    end
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:user) }
  let(:user_registration_organization) do
    FactoryBot.create(:user_registration_organization, user:, organization:,
      registration_info: {"user_name" => "Alice Ambassador"}, all_bikes: true)
  end

  it "renders the user and organization links, the checks and the registration info" do
    expect(component).to have_css("a[href='/admin/users/#{user.id}']")
    expect(component).to have_css("a[href='/admin/organizations/#{organization.id}']")
    expect(component).to have_css("a[href*='organization_id=#{organization.id}']")
    expect(component).to have_css("div.twjson-box[style='max-width: 300px;']")
    expect(component.text).to include "Alice Ambassador"
    expect(component.text).to include user.display_name
  end

  context "with the user deleted" do
    before { user.really_destroy! && user_registration_organization.reload }

    it "marks the user missing rather than linking nothing" do
      expect(component.text).to include "Missing user"
      expect(component).to_not have_css("a[href='/admin/users/#{user.id}']")
    end
  end
end
