# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Checkbox::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/checkbox/component/" }

  it "toggles when the wrapping label is clicked" do
    visit("#{base_path}default")

    expect(page).to have_field("Email me updates", type: "checkbox", checked: false)
    expect_axe_clean

    find("label", text: "Email me updates").click
    expect(page).to have_field("Email me updates", checked: true)

    find("label", text: "Email me updates").click
    expect(page).to have_field("Email me updates", checked: false)

    # The form builder variant wraps check_box's hidden companion input too
    visit("#{base_path}form_builder")

    expect(page).to have_field("I agree to the terms", type: "checkbox", checked: false)

    find("label", text: "I agree to the terms").click
    expect(page).to have_field("I agree to the terms", checked: true)
  end
end
