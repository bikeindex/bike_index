# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::InternalNotes::Component, type: :component do
  it "renders a note whose author was deleted" do
    render_preview(:author_deleted)

    expect(page).to have_text("Written by someone who has since left.")
  end
end
