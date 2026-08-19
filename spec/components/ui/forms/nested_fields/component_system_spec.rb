# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::NestedFields::Component, :js, type: :system do
  let!(:location) { FactoryBot.create(:location) }
  let(:wrapper) { ".nested-fields-wrapper" }

  before { visit "/rails/view_components/ui/forms/nested_fields/component/default" }

  it "adds a set of fields per click, each submitting as its own record" do
    expect(page).to have_css(wrapper, count: 1)
    expect_axe_clean

    click_link "Add a location"
    click_link "Add a location"

    expect(page).to have_css(wrapper, count: 3)
    # Every set has to carry a distinct child index, or they collapse into one record on submit
    names = page.all("input[name*='locations_attributes'][name$='[name]']", visible: :all).map { |input| input[:name] }
    expect(names.uniq.count).to eq 3
    expect(names.grep(/__INDEX__/)).to be_empty
    # The link stays below the sets it adds
    expect(page).to have_css("#{wrapper} + span + a", text: "Add a location")
    expect_axe_clean
  end

  it "detaches a removed new record, and marks a removed saved one for destruction" do
    click_link "Add a location"

    within(all(wrapper).last) { click_button "Remove" }

    # Nothing to destroy, so it leaves no hidden inputs behind to submit or block validation
    expect(page).to have_css(wrapper, count: 1, visible: :all)

    within(all(wrapper).first) { click_button "Remove" }

    expect(page).to have_css(wrapper, count: 0)
    # Hidden rather than detached, so the _destroy it just set still submits
    expect(page).to have_css(wrapper, count: 1, visible: :all)
    expect(page.all("input[name$='[_destroy]']", visible: :all).map(&:value)).to eq ["1"]
  end
end
