# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWrap::AddressRecord::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/legacy_form_wrap/address_record/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "LegacyFormWrap::AddressRecord::Component"
  end
end
