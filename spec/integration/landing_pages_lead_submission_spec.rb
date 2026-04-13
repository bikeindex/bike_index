# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing page demo modals", :js, type: :system do
  def log_in_via_browser(user)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_current_path("/my_account", wait: 5)
  end

  def fill_in_and_submit_demo_form(name_label:, name_value:, email: nil)
    expect(page).to have_content("Contact us for a free trial", wait: 5)
    fill_in name_label, with: name_value
    fill_in "Phone number", with: "5551234567"
    fill_in "Email", with: email if email
    click_button "Sign up"
  end

  context "for_schools" do
    let(:target_attributes) do
      {kind: "lead_for_school", name: "Test University", email: "admin@testuni.edu",
       phone_number: "5551234567", title: "New School lead: Test University"}
    end

    it "submits a school lead via hero button" do
      visit "/for_schools"
      expect(page).to have_content("campus bike management")
      first("button[data-open-modal]").click

      expect {
        fill_in_and_submit_demo_form(name_label: "School", name_value: "Test University", email: "admin@testuni.edu")
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      expect(Feedback.last).to have_attributes(target_attributes)

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "for_law_enforcement" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:target_attributes) do
      {kind: "lead_for_city", name: "Portland", email: user.email,
       phone_number: "5551234567", title: "New City lead: Portland"}
    end

    it "submits a city lead via CTA button" do
      log_in_via_browser(user)
      visit "/for_law_enforcement"
      expect(page).to have_content("bike theft recovery")
      find(".le-cta-section button[data-open-modal]").click

      expect {
        fill_in_and_submit_demo_form(name_label: "City", name_value: "Portland")
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      expect(Feedback.last).to have_attributes(target_attributes)

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end
end
