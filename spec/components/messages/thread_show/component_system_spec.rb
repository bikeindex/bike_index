# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ThreadShow::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/messages/thread_show/component/buyer" }
  let!(:user) { FactoryBot.create(:user_confirmed) }

  before { ENV["LOOKBOOK_USER_ID"] = user.id.to_s }

  it "buyer preview" do
    visit(preview_path)

    expect(page).to have_content "When are you available"

    expect(page).to have_content("Me (")
  end

  context "seller preview" do
    let(:preview_path) { "/rails/view_components/messages/thread_show/component/seller" }
    it "renders preview" do
      visit(preview_path)

      expect(page).to have_content "When are you available"
      expect(page).to have_content("to me")
    end
  end
end
