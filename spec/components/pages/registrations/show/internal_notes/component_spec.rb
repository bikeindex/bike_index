# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::InternalNotes::Component, type: :component do
  it "names a deleted author in the history" do
    render_preview(:with_previous_notes)

    expect(page).to have_text(/Note by Alice Staff.*Updated by a deleted user.*Updated by Bob Member/m)
  end
end
