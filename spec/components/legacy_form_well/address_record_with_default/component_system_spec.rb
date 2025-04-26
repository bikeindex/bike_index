# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecordWithDefault::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/legacy_form_well/address_record_with_default/component/default" }

  it "default preview" do
    FactoryBot.create(:state_california)
    FactoryBot.create(:state_new_york)
    Country.canada
    visit(preview_path)


    expect(page).to have_content "Use default address"
  end
end
