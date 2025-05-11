# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::Threads::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/messages/threads/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Messages::Threads::Component"
  end
end
