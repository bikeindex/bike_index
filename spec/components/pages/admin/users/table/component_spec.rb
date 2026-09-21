# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Users::Table::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed, name: "Sally Rider") }
  let(:component) do
    with_controller_class(Admin::UsersController) do
      with_request_url("/admin/users") { render_inline(described_class.new(users: [user])) }
    end
  end

  it "renders a row for each user" do
    expect(component).to have_css("td", text: "Sally Rider")
    expect(component).to have_css("td", text: user.email)
  end

  let(:cached_record) { user }
  it_behaves_like "cached_table_cells"
end
