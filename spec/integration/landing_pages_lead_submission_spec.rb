# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing page demo modals", :js, type: :system do
  def fill_in_and_submit_demo_form(name_label:, name_value:, contact_name: "Jane Doe", email: nil)
    expect(page).to have_content("Contact us for a free trial", wait: 5)
    fill_in "Your name", with: contact_name
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
      fill_in "Your name", with: "Jane Doe"
      fill_in "School", with: "Test University"
      fill_in "Phone number", with: "5551234567"
      fill_in "Email", with: "admin@testuni.edu"

      page.refresh

      # have_content/have_field only match visible text, so these assert the modal
      # reopened (URL param) with entered data restored (form-persist localStorage)
      expect(page).to have_content("Contact us for a free trial", wait: 5)
      expect(page).to have_field("Your name", with: "Jane Doe")
      expect(page).to have_field("School", with: "Test University")
      expect(page).to have_field("Phone number", with: "5551234567")
      expect(page).to have_field("Email", with: "admin@testuni.edu")

      expect {
        click_button "Let's chat"
        expect(page).to have_content("Thank", wait: 5)
      }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
      expect(page).to have_no_css("dialog[open]")

      expect(Feedback.last).to have_attributes(target_attributes)

      EmailJobs::FeedbackNotificationJob.drain
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

  context "for_cities" do
    let(:target_attributes) do
      {kind: "lead_for_city", name: "Portland", email: "staff@portland.gov", contact_name: "Jane Doe",
       contact_role: "city_staff", phone_number: "(555) 123-4567 ext. 12", body: "Starting with e-bikes", title: "New City lead: Portland"}
    end

    it "walks through the education flow, then requests a demo from the contact section" do
      visit "/for_cities"
      expect(page).to have_content("Register every bike in your city")

      within("#tab-school") do
        expect(page).to have_button("Continue", disabled: true)
        find_button(text: "Riding practices").click
        expect(page).to have_content("Westbrook rules for helmets, lanes, speed, and sidewalks.")
        # The demo finishes from the final review alone, whatever's left unchecked before it
        find_button(text: "Final review").click
        check "have read, understood, and agree"
        click_button "Complete registration"
        expect(page).to have_content("You're all set.")
        click_button "Start over"
        expect(page).to have_content("Westbrook has a few e-bike rules to go over")
        check "I will charge only with a manufacturer-approved charger."
        check "I will never leave my battery charging unattended."
        expect(page).to have_button("Continue", disabled: true)
        check "I will keep my battery away from flammable materials."
        click_button "Continue"
        expect(page).to have_content("Westbrook rules for helmets, lanes, speed, and sidewalks.")
        click_button "Back"
        expect(page).to have_content("Westbrook has a few e-bike rules to go over")
        find_button(text: "Riding practices").click
        # The school carries the city's pages, then adds its own
        expect(page).to have_content("Set by City of Westbrook")
        check "I will wear a helmet whenever I ride if I am under 18."
        check "I will ride in bike lanes where they exist and keep under 15 mph on shared paths."
        check "I will not ride on sidewalks in the downtown business district."
        click_button "Continue"
        check "I will ride a Class 3 e-bike only if I am 16 or older, and not on the Riverside Trail."
        check "I will park only at public bike racks, never blocking sidewalks, ramps, or doorways."
        check "I know where to find Westbrook's free e-bike safety classes."
        click_button "Continue"
        expect(page).to have_content("Set by Westbrook Middle School")
        check "I will ride only a Class 1 e-bike to school."
        check "I will walk my bike from the front gate to the racks."
        check "I will follow traffic laws and yield to pedestrians and crossing guards."
        check "I have reviewed these rules with a parent or guardian."
        click_button "Continue"
        expect(page).to have_content("You're almost done.")
        expect(page).to have_button("Complete registration", disabled: true)
        check "have read, understood, and agree"
        click_button "Complete registration"
        expect(page).to have_content("You're all set.")
      end

      # The tab and step are in the URL, so a reload comes back to them
      click_button "Housing Authority"
      within("#tab-housing") { find_button(text: "Building rules").click }
      expect(page).to have_current_path(/education=housing/).and have_current_path(/education_step=4/)
      page.refresh
      expect(page).to have_css("[role=tab][aria-selected=true]", text: "Housing Authority")
      within("#tab-housing") { expect(page).to have_content("Storage and parking") }
      # Another tab opens on the same step - the city's fourth is its review
      click_button "City of Westbrook"
      within("#tab-city") { expect(page).to have_content("You're almost done.") }

      open_modal(find("section", text: "Talk to us about your city").find("button[commandfor]"))
      expect(page).to have_content("Schedule a demo")
      fill_in "City or organization", with: "Portland"

      # the modal reopens with what was entered, like the other landing pages'
      page.refresh
      expect(page).to have_field("City or organization", with: "Portland", wait: 5)

      # name, role and phone are required along with the email
      click_button "Request a demo"
      expect(page.evaluate_script("document.activeElement.id")).to eq "feedback_contact_name"
      fill_in "Your name", with: "Jane Doe"
      click_button "Request a demo"
      expect(page.evaluate_script("document.activeElement.id")).to eq "feedback_contact_role"
      select "City staff", from: "Your role"
      fill_in "Email", with: "staff@portland.gov"
      click_button "Request a demo"
      expect(page.evaluate_script("document.activeElement.id")).to eq "feedback_phone_number"
      fill_in "Phone number", with: "(555) 123-4567 ext. 12"
      fill_in "Anything else we should know?", with: "Starting with e-bikes"

      expect {
        click_button "Request a demo"
        expect(page).to have_content("Thanks. We'll be in touch soon.", wait: 5)
      }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_no_content("Book a discovery call")

      expect(Feedback.last).to have_attributes(target_attributes)

      EmailJobs::FeedbackNotificationJob.drain
      body = ActionMailer::Base.deliveries.last.body.encoded
      expect(body).to include("Role: City staff")
      expect(body).to include("(555) 123-4567 ext. 12")
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
      }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)

      expect(Feedback.last).to have_attributes(target_attributes)

      EmailJobs::FeedbackNotificationJob.drain
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
