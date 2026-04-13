# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing page demo modals", :js, type: :system do
  def fill_in_and_submit_demo_form(name_label:, name_value:, email:)
    expect(page).to have_content("Contact us for a free trial", wait: 5)
    fill_in name_label, with: name_value
    fill_in "Phone number", with: "5551234567"
    fill_in "Email", with: email
    click_button "Sign up"
  end

  context "for_schools" do
    it "submits a school lead via hero button" do
      visit "/for_schools"
      expect(page).to have_content("campus bike management")
      first("button[data-open-modal]").click

      expect {
        fill_in_and_submit_demo_form(name_label: "School", name_value: "Test University", email: "admin@testuni.edu")
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      feedback = Feedback.last
      expect(feedback.kind).to eq "lead_for_school"
      expect(feedback.name).to eq "Test University"
      expect(feedback.email).to eq "admin@testuni.edu"
      expect(feedback.phone_number).to eq "5551234567"
      expect(feedback.title).to eq "New School lead: Test University"

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "for_law_enforcement" do
    it "submits a city lead via CTA button" do
      visit "/for_law_enforcement"
      expect(page).to have_content("bike theft recovery")
      find(".le-cta-section button[data-open-modal]").click

      expect {
        fill_in_and_submit_demo_form(name_label: "City", name_value: "Portland", email: "officer@portland.gov")
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      feedback = Feedback.last
      expect(feedback.kind).to eq "lead_for_city"
      expect(feedback.name).to eq "Portland"
      expect(feedback.email).to eq "officer@portland.gov"
      expect(feedback.phone_number).to eq "5551234567"
      expect(feedback.title).to eq "New City lead: Portland"

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end
end
