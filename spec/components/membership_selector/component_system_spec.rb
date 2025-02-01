# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipSelector::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components//membership_selector/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "MembershipSelector::Component"
  end
end
