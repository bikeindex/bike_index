# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ActiveLink::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/active_link/component" }

  it "resolves what each link covers against the page the browser is on" do
    visit "#{preview_path}/current_page"
    expect(page).to have_css "a[aria-current='page']", text: "This preview"

    # Every scenario is a path below the group's own, which ** takes and the default doesn't
    visit "#{preview_path}/match_paths_default"
    expect(page).to have_css "a.twlink", text: "A sibling preview"
    expect(page).to_not have_css "a[aria-current]"

    # A pattern wider than the link's own path is only "true" -- the page isn't the one the
    # link points at
    visit "#{preview_path}/match_paths_below"
    expect(page).to have_css "a[aria-current='true']", text: "A sibling preview"

    # Naming this page in a pattern doesn't make the link point at it, so it's "true" too
    visit "#{preview_path}/match_paths_other_page"
    expect(page).to have_css "a[aria-current='true']", text: "A sibling preview"

    # A * stands for the "component" segment this page is served under
    visit "#{preview_path}/match_paths_one_segment"
    expect(page).to have_css "a[aria-current='true']", text: "This preview, through a wildcard segment"

    visit "#{preview_path}/default"
    expect(page).to_not have_css "a[aria-current]"

    # A link naming no params ignores the page's own
    visit "#{preview_path}/current_page?example=1"
    expect(page).to have_css "a[aria-current='page']", text: "This preview"

    # A filter entry stands for the param it applies rather than for a URL, so it goes active
    # on a page it doesn't point at and stays active under a page number it never carries
    visit "#{preview_path}/match_params"
    expect(page).to have_css "a.twlink", text: "Filter: on"
    expect(page).to_not have_css "a[aria-current]"

    # The entry links away from its own filter, the way one already in force clears itself
    visit "#{preview_path}/match_params?filter=on&page=2"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: on"

    # BLANK is among the default entry's values, so it's current either way it's written
    visit "#{preview_path}/match_params_blank"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: off"

    visit "#{preview_path}/match_params_blank?filter=off"
    expect(page).to have_css "a[aria-current='true']", text: "Filter: off"

    # A param the URL leaves empty is one the page doesn't carry, the way BLANK reads it
    visit "#{preview_path}/match_params_blank?filter="
    expect(page).to have_css "a[aria-current='true']", text: "Filter: off"

    visit "#{preview_path}/match_params_blank?filter=on"
    expect(page).to_not have_css "a[aria-current]"

    # The navbar renders from a fragment cache shared by every page it was rendered for, so
    # the current page can't be in the cached markup
    visit "/help"
    expect(page).to have_css "#primary-main-menu a[aria-current]", text: "Help", visible: :all
    expect(page).to have_css "#primary-main-menu a[aria-current]", count: 1, visible: :all

    # Both search links carry a stolenness this page doesn't, which naming no params ignores
    visit "/search/registrations?query=trek"
    expect(page).to have_css "#primary-main-menu a[aria-current='page']", text: "Search", count: 2, visible: :all
  end
end
