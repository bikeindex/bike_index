# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddressGroup::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/forms/address_group/component/required" }
  let(:state_select) { "select[name='address_record[region_record_id]']" }
  let(:region_input) { "input[name='address_record[region_string]']" }

  it "moves required to whichever of the state/region pair the country shows" do
    FactoryBot.create(:state_california)
    Country.canada
    visit(preview_path)
    expect_axe_clean("select-name")

    expect(page).to have_css("#{state_select}[required]")
    expect(page).to have_css("#{region_input}:not([required])", visible: :all)

    select "Canada", from: "address_record[country_id]"
    expect(page).to have_css("#{region_input}[required]")
    expect(page).to have_css("#{state_select}:not([required])", visible: :all)

    select "United States", from: "address_record[country_id]"
    expect(page).to have_css("#{state_select}[required]")
    expect(page).to have_css("#{region_input}:not([required])", visible: :all)
  end
end
