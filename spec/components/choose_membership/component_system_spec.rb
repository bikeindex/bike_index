# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChooseMembership::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components//choose_membership/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "ChooseMembership::Component"
  end
end
