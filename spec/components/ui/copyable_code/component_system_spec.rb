# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::CopyableCode::Component, :js, type: :system do
  def copy_button_over_code?
    page.evaluate_script(<<~JS)
      (() => {
        const code = document.querySelector("code").getBoundingClientRect();
        const button = document.querySelector("button[title='Copy ID']").getBoundingClientRect();
        return button.left >= code.left && button.right <= code.right;
      })()
    JS
  end

  it "puts the copy button beside the code, or over it when the code overflows" do
    visit "/rails/view_components/ui/copyable_code/component/default"
    expect(page).to have_button("Copy ID")
    expect(copy_button_over_code?).to be false

    visit "/rails/view_components/ui/copyable_code/component/overflowing"
    expect(page).to have_css("[data-overflowing]")
    expect(copy_button_over_code?).to be true
  end
end
