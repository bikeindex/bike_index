# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing page demo modals", :js, type: :system do
  def fill_in_and_submit_demo_form(name_label:, name_value:, contact_name: "Jane Doe", email: nil)
    expect(page).to have_content("Contact us for a free trial", wait: 5)
    fill_in "Name", with: contact_name
    fill_in name_label, with: name_value
    fill_in "Phone number", with: "5551234567"
    fill_in "Email", with: email if email
    click_button "Let's chat"
  end

  context "for_schools" do
    let(:target_attributes) do
      {kind: "lead_for_school", name: "Test University", email: "admin@testuni.edu",
       contact_name: "Jane Doe", phone_number: "5551234567", title: "New School lead: Test University"}
    end

    it "submits a school lead via hero button, persisting entry across a reload" do
      visit "/for_schools"
      expect(page).to have_content("campus bike management")
      open_modal(first("button[commandfor]"))

      expect(page).to have_content("Contact us for a free trial", wait: 5)
      fill_in "Name", with: "Jane Doe"
      fill_in "School", with: "Test University"
      fill_in "Phone number", with: "5551234567"
      fill_in "Email", with: "admin@testuni.edu"

      page.refresh

      # have_content/have_field only match visible text, so these assert the modal
      # reopened (URL param) with entered data restored (form-persist localStorage)
      expect(page).to have_content("Contact us for a free trial", wait: 5)
      expect(page).to have_field("Name", with: "Jane Doe")
      expect(page).to have_field("School", with: "Test University")
      expect(page).to have_field("Phone number", with: "5551234567")
      expect(page).to have_field("Email", with: "admin@testuni.edu")

      expect {
        click_button "Let's chat"
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      expect(Feedback.last).to have_attributes(target_attributes)

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq "New School lead: Test University"
      body = mail.body.encoded
      expect(body).to include("admin@testuni.edu")
      expect(body).to include("Test University")
      expect(body).to include("Jane Doe")
      expect(body).to include("5551234567")
    end
  end

  context "for_law_enforcement" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:target_attributes) do
      {kind: "lead_for_city", name: "Portland", email: user.email,
       contact_name: "Jane Doe", phone_number: "5551234567", title: "New City lead: Portland"}
    end

    it "submits a city lead via CTA button" do
      sign_in(user)
      expect(page).to have_current_path("/my_account")
      visit "/for_law_enforcement"
      expect(page).to have_content("bike theft recovery")
      open_modal(".le-cta-section button[commandfor]")

      expect {
        fill_in_and_submit_demo_form(name_label: "City", name_value: "Portland")
        expect(page).to have_content("Thank", wait: 5)
      }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)

      expect(Feedback.last).to have_attributes(target_attributes)

      Email::FeedbackNotificationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq "New City lead: Portland"
      body = mail.body.encoded
      expect(body).to include(user.email)
      expect(body).to include("Portland")
      expect(body).to include("Jane Doe")
      expect(body).to include("5551234567")
    end
  end
end
