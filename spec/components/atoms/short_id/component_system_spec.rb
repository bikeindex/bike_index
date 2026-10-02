# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::ShortId::Component, :js, type: :system do
  def copy_button_over_id?
    page.evaluate_script(<<~JS)
      (() => {
        const id = document.querySelector("code").getBoundingClientRect();
        const button = document.querySelector("button[title='Copy ID']").getBoundingClientRect();
        return button.left >= id.left && button.right <= id.right;
      })()
    JS
  end

  it "puts the copy button beside the ID, or over it when the ID overflows" do
    visit "/rails/view_components/atoms/short_id/component/default"
    expect(page).to have_button("Copy ID")
    expect(copy_button_over_id?).to be false

    visit "/rails/view_components/atoms/short_id/component/overflowing"
    expect(page).to have_css("[data-overflowing]")
    expect(copy_button_over_id?).to be true
  end
end
