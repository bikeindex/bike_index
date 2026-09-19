# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::InternalNotes::Component, type: :component do
  it "renders a note whose author was deleted" do
    render_preview(:author_deleted)

    expect(page).to have_text("Written by someone who has since left.")
  end

  it "renders only the form without notes" do
    render_preview(:no_notes)

    expect(page).to have_no_text("Note by")
    expect(page).to have_button("Post note")
  end
end
