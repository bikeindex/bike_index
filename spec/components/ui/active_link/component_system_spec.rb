# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ActiveLink::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/active_link/component" }

  it "resolves each match against the page the browser is on" do
    visit "#{preview_path}/current_page"
    expect(page).to have_css "a[aria-current='page']", text: "This preview"

    # Every scenario is served by the preview controller, so a link to a sibling scenario
    # is the same page to :controller and a different one to :path
    visit "#{preview_path}/match_path"
    expect(page).to have_css "a.twlink", text: "A sibling preview"
    expect(page).to_not have_css "a[aria-current]"

    # A widened match is only "true" -- the page isn't the one the link points at
    visit "#{preview_path}/match_controller"
    expect(page).to have_css "a[aria-current='true']", text: "A sibling preview"

    # The link carries a param the page doesn't
    visit "#{preview_path}/match_controller_action"
    expect(page).to have_css "a[aria-current='true']", text: "This scenario, other params"

    visit "#{preview_path}/default"
    expect(page).to_not have_css "a[aria-current]"

    # The param the page carries is what :path ignores and :full_path doesn't
    visit "#{preview_path}/match_full_path"
    expect(page).to have_css "a[aria-current='page']", text: "This preview, exactly"

    visit "#{preview_path}/match_full_path?example=1"
    expect(page).to have_css "a.twlink", text: "This preview, exactly"
    expect(page).to_not have_css "a[aria-current]"

    visit "#{preview_path}/current_page?example=1"
    expect(page).to have_css "a[aria-current='page']", text: "This preview"

    # A filter entry stands for the param it applies rather than for a URL, so it goes active
    # on a page it doesn't point at and stays active under a page number it never carries
    visit "#{preview_path}/match_query"
    expect(page).to have_css "a.twlink", text: "Filter: on"
    expect(page).to_not have_css "a[aria-current]"

    # The entry links away from its own filter, the way one already in force clears itself
    visit "#{preview_path}/match_query?filter=on&page=2"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: on"

    # Absent is among the default entry's values, so it's current either way it's written
    visit "#{preview_path}/match_query_default"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: off"

    visit "#{preview_path}/match_query_default?filter=off"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: off"

    visit "#{preview_path}/match_query_default?filter=on"
    expect(page).to_not have_css "a[aria-current]"

    # The navbar renders from a fragment cache shared by every page it was rendered for, so
    # the current page can't be in the cached markup
    visit "/help"
    expect(page).to have_css "#primary-main-menu a[aria-current]", text: "Help", visible: :all
    expect(page).to have_css "#primary-main-menu a[aria-current]", count: 1, visible: :all

    # Both search links carry a stolenness this page doesn't, so they match on route
    visit "/search/registrations?query=trek"
    expect(page).to have_css "#primary-main-menu a[aria-current='true']", text: "Search", count: 2, visible: :all
  end
end
