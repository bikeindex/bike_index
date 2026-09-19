# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::InternalNotes::Component, type: :component do
  it "renders a note whose author was deleted" do
    render_preview(:author_deleted)

    expect(page).to have_field("Current note", with: "Written by someone who has since left.")
    expect(page).to have_no_css("label small", text: "update by")
  end
end
