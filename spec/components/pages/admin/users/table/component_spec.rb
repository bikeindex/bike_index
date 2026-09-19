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

  # Action View's template digest can't see the components these cell blocks render, so
  # the row key carries this component's own digest of them
  describe "row caching" do
    include_context :caching_basic

    it "keys each row to its record and this component's markup digest", :caching do
      keys = fragments_written { component }

      expect(keys.count).to eq 1
      expect(keys.first).to include(%(admin-users-#{described_class.cache_digest}), user.cache_key_with_version)
    end
  end
end
