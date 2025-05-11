# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::Thread::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/messages/thread/component/default" }
  let!(:user) { FactoryBot.create(:user_confirmed) }
  # let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, seller: user) }
  # let!(:marketplace_message) { FactoryBot.create(:marketplace_message, receiver: user, marketplace_listing:) }

  before { ENV["LOOKBOOK_USER_ID"] = user.id.to_s }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "John Smith"
  end
end
