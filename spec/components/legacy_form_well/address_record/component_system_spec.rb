# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecord::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/legacy_form_well/address_record/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Street address"
  end
end
