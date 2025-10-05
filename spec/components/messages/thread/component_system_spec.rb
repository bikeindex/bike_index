# frozen_string_literal: true

require "rails_helper"

# As of now, this just verifies that the preview renders
RSpec.describe Messages::Thread::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/messages/thread/component/default" }
  let!(:user) { FactoryBot.create(:user_confirmed) }

  before { ENV["LOOKBOOK_USER_ID"] = user.id.to_s }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "John Smith"
  end
end
