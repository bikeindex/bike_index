# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddFields::Component, :js, type: :system do
  let(:organization) { FactoryBot.create(:organization) }
  let!(:location) { FactoryBot.create(:location, organization:) }
  let(:fields_selector) { "[data-controller='ui--forms--remove-fields']" }
  let(:name_inputs) { page.all("input[name*='locations_attributes'][name$='[name]']", visible: :all) }

  it "adds a set of fields per click, each submitting as its own record, and removes them" do
    visit "/rails/view_components/ui/forms/add_fields/component/default"

    expect(page).to have_css(fields_selector, count: 1)

    click_link "Add a location"

    expect(page).to have_css(fields_selector, count: 2)

    click_link "Add a location"

    expect(page).to have_css(fields_selector, count: 3)
    # Every set has to carry a distinct child index, or they collapse into one record on submit
    expect(name_inputs.map { |input| input[:name] }.uniq.count).to eq 3

    # The link stays below the fields it adds
    expect(page).to have_css("#{fields_selector} + a", text: "Add a location")

    within(all(fields_selector).last) do
      find("label", text: "Remove").click
    end

    expect(page).to have_css(fields_selector, count: 2)
    # Hidden rather than detached, so the _destroy it just checked still submits
    expect(page).to have_css(fields_selector, count: 3, visible: :all)
    expect(page.all("input[name$='[_destroy]'][type='checkbox']", visible: :all).count(&:checked?)).to eq 1
  end
end
