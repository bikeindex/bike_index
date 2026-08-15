# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddFields::Component, :js, type: :system do
  let!(:location) { FactoryBot.create(:location) }
  let(:fields_selector) { "[data-ui--collapse-target='content']" }

  it "adds a set of fields per click, each submitting as its own record, and removes them" do
    visit "/rails/view_components/ui/forms/add_fields/component/default"

    expect(page).to have_css(fields_selector, count: 1)
    expect_axe_clean

    click_link "Add a location"

    expect(page).to have_css(fields_selector, count: 2)

    click_link "Add a location"

    expect(page).to have_css(fields_selector, count: 3)
    # Every set has to carry a distinct child index, or they collapse into one record on submit
    names = page.all("input[name*='locations_attributes'][name$='[name]']", visible: :all).map { |input| input[:name] }
    expect(names.uniq.count).to eq 3
    expect(names.grep(/__INDEX__/)).to be_empty
    expect(page).to have_css("#{fields_selector} + a", text: "Add a location")
    expect_axe_clean

    within(all(fields_selector).last) { find("label", text: "Remove").click }

    expect(page).to have_css(fields_selector, count: 2)
    # Hidden rather than detached, so the _destroy it just checked still submits
    expect(page).to have_css(fields_selector, count: 3, visible: :all)
    expect(page.all("input[name$='[_destroy]'][type='checkbox']", visible: :all).count(&:checked?)).to eq 1
  end
end
