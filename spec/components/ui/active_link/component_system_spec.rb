# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ActiveLink::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/active_link/component" }

  it "resolves each match against the page in the browser" do
    visit "#{preview_path}/current_page"
    expect(page).to have_css "a.active", text: "This preview"

    # Every scenario is served by the preview controller, so a link to a sibling scenario
    # is the same page to :controller and a different one to :path
    visit "#{preview_path}/match_path"
    expect(page).to have_css "a.nav-link", text: "A sibling preview"
    expect(page).to_not have_css "a.active"

    visit "#{preview_path}/match_controller"
    expect(page).to have_css "a.active", text: "A sibling preview"

    # The link carries a param the page doesn't
    visit "#{preview_path}/match_controller_action"
    expect(page).to have_css "a.active", text: "This scenario, other params"

    visit "#{preview_path}/default"
    expect(page).to_not have_css "a.active"
  end

  # The navbar renders from a fragment cache shared by every page it was rendered for, so
  # the active link can't be in the cached markup
  it "marks the navbar's link to the page being viewed" do
    visit "/help"
    expect(page).to have_css "#primary-main-menu a.active", text: "Help", visible: :all
    expect(page).to have_css "#primary-main-menu a.active", count: 1, visible: :all

    # Both search links carry a stolenness this page doesn't, so they match on route
    visit "/search/registrations?query=trek"
    expect(page).to have_css "#primary-main-menu a.active", text: "Search", count: 2, visible: :all
  end
end
