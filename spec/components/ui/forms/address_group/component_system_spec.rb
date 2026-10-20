# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddressGroup::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/forms/address_group/component/required" }
  let(:state_input) { "[data-ui--forms--address-group-target='state'] .hw-combobox__input" }
  let(:state_value) { "input[type='hidden'][name='address_record[region_record_id]']" }
  let(:region_input) { "input[name='address_record[region_string]']" }

  it "moves required to whichever of the state/region pair the country shows, clearing a state a country leaves" do
    california = FactoryBot.create(:state_california)
    Country.canada
    visit(preview_path)
    wait_for_stimulus("ui--forms--address-group")
    expect_axe_clean

    expect(page).to have_css("#{state_input}[required]")
    expect(page).to have_css("#{region_input}:not([required])", visible: :all)

    type_into(find(state_input), "CA")
    click_combobox_option("California (CA)")
    expect(find(state_value, visible: :all).value).to eq california.id.to_s

    select "Canada", from: "address_record[country_id]"
    expect(page).to have_css("#{region_input}[required]")
    expect(page).to have_css("#{state_input}:not([required])", visible: :all)
    expect(find(state_value, visible: :all).value).to eq ""

    select "United States", from: "address_record[country_id]"
    expect(page).to have_css("#{state_input}[required]")
    expect(page).to have_css("#{region_input}:not([required])", visible: :all)
    expect(find(state_input).value).to eq ""
  end
end
