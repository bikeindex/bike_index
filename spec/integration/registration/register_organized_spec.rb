# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Register flow, with an organization", :js, type: :system do
  include_context :register_flow_steps

  let!(:state) { FactoryBot.create(:state_new_york) }

  describe "signed in" do
    let(:current_user) { FactoryBot.create(:user_confirmed, email: owner_email) }

    before do
      sign_in(current_user)
      expect(page).to have_current_path("/my_account")
    end

    # The one organization they're in, assigned without any link naming it
    context "a member of one organization" do
      let(:organization) do
        FactoryBot.create(:organization, short_name: "Brakebills").tap do
          # set_calculated_attributes recomputes the slugs from the invoices, so assigning them won't hold
          it.update_column :enabled_feature_slugs, %w[reg_student_id require_reg_student_id]
        end
      end
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

      it "registers with it unless the rider says otherwise, taking its asks with it" do
        start_registration
        expect(page).to have_checked_field("register_with_organization")
        expect(page).to have_content(/information for brakebills/i)
        expect(page).to have_field("bike[student_id]")
        # It heads the section whose contents it decides
        expect(page.text.index(/information for brakebills/i))
          .to be < page.text.index("Register with Brakebills")

        type_into("#bike_primary_frame_color_id", "Red")
        click_combobox_option("Red")
        fill_in "bike[serial_number]", with: "XYZ 123"

        # Student ID is required, so the browser holds the submit while the organization is on
        click_button "Complete Bike Registration"
        expect(page).to have_current_path(/step=2/, url: true)
        expect(Bike.count).to eq 0

        # Dropping the organization drops what it asks for, required and all - and the
        # heading, which can't go with them, the checkbox being under it
        uncheck "Register with Brakebills"
        expect(page).to have_no_field("bike[student_id]")
        expect(page).to have_content(/contact info/i)
        expect(page).to have_no_content(/information for brakebills/i)

        # Collapsed rather than dropped, so changing their mind brings all of it back
        check "Register with Brakebills"
        expect(page).to have_field("bike[student_id]")
        expect(page).to have_content(/information for brakebills/i)

        uncheck "Register with Brakebills"
        expect(page).to have_no_field("bike[student_id]")

        click_button "Complete Bike Registration"
        expect(page).to have_content("Registration complete")
        expect(Bike.last.creation_organization_id).to be_blank
        expect(Bike.last.organizations.pluck(:id)).to eq([])
      end
    end
  end

  context "e-vehicle with an organization's safety rules" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    # Built as a draft and activated below, since activation freezes the pages
    let(:sequence) do
      FactoryBot.create(:registration_sequence, organization:,
        acknowledgment_text: "agree to comply with all of the rules above.")
    end
    let!(:battery_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 0,
        title: "Battery & charging", subtitle: "Unsafe charging is the biggest cause of e-bike fires.",
        body: "<ul><li>Charge with the manufacturer's charger</li><li>Report a swollen battery</li></ul>")
    end
    let!(:campus_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 1,
        title: "Campus rules", body: "<ul><li>Dismount in posted zones</li></ul>",
        organization_specific: true)
    end

    before { sequence.make_active! }

    # flaky: the color combobox below is typed into right after step 1's Turbo navigation,
    # and filters nothing when its controller hasn't connected yet. wait_for_details_step
    # proves hydration now - the retries stay until CI has run green a few times
    it "gates each page of rules, then the acknowledgment, before completing", flaky: 4 do
      visit "/register/new?organization_id=#{organization.slug}"

      type_into("#b_param_manufacturer_id", "Surly")
      click_combobox_option("Surly")
      check "Electric (motorized)"
      fill_in "b_param[owner_email]", with: owner_email
      click_button "Next"

      wait_for_details_step
      fill_in "bike[user_name]", with: user_name
      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "XYZ 123"
      # The safety pages come next, so step 2 no longer finishes the registration
      click_button "Next"

      expect(page).to have_content("Battery & charging")
      expect(page).to have_content("Electric (motorized) detected")
      expect(page).to have_content("E-Vehicle Acknowledgment · Step 1 of 3")
      expect(page).to have_button("Continue", disabled: true)

      check "Charge with the manufacturer's charger"
      expect(page).to have_button("Continue", disabled: true)
      check "Report a swollen battery"
      click_button "Continue"

      expect(page).to have_content("Campus rules")
      # The organization owns this page's rules, so they carry its name
      expect(page).to have_content("Brakebills")
      check "Dismount in posted zones"
      click_button "Continue"

      expect(page).to have_content("You're almost done")
      expect(page).to have_content("agree to comply with all of the rules above")
      expect(page).to have_button("Complete Bike Registration", disabled: true)

      # A page stays revisitable from the review, showing what was agreed to
      click_link "Review", match: :first
      expect(page).to have_content("Battery & charging")
      expect(page).to have_checked_field("Report a swollen battery")

      # Continuing walks forward through the remaining pages rather than jumping
      # straight back to the review
      click_button "Continue"
      expect(page).to have_content("Campus rules")
      click_button "Continue"

      expect(page).to have_content("You're almost done")
      # Registered for someone else, so it's their name that agrees
      check "I, #{user_name}, agree to comply with all of the rules above."
      click_button "Complete Bike Registration"

      expect(page).to have_css("h1", text: "Progress saved")
      acknowledgment = RegistrationSequenceAcknowledgment.last
      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: BParam.last.id, owner_email:,
        acknowledgment_text: "agree to comply with all of the rules above.")
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array([battery_page.id, campus_page.id])
    end

    # Every step submits through Turbo, so a throttle or a bad gateway is a response the
    # page can retry. This flow has one of every step, so each gets its turn at failing.
    context "when the server fails each step once" do
      let(:failed_steps) { [] }

      def step_param(url) = Rack::Utils.parse_query(URI.parse(url.to_s).query)["step"]

      # Each step's first submission is answered in the browser and the retry behind it is
      # let through. The statuses alternate, so both kinds of failure get their turn.
      before do
        page.driver.with_playwright_page do |playwright_page|
          playwright_page.route(%r{/register}, ->(route, request) {
            # Every submission is a POST to one of three paths (Rails' method override),
            # so what tells the steps apart is the page each came from
            step = [URI.parse(request.url).path, step_param(request.headers["referer"])]
            next route.continue if request.method == "GET" || failed_steps.include?(step)

            failed_steps << step
            route.fulfill(status: failed_steps.length.odd? ? 429 : 500,
              contentType: "text/plain", body: "Try again")
          })
        end
      end

      it "retries each of them, and the registration still finishes" do
        ActionMailer::Base.deliveries = []
        visit "/register/new?organization_id=#{organization.slug}"

        type_into("#b_param_manufacturer_id", "Surly")
        click_combobox_option("Surly")
        check "Electric (motorized)"
        fill_in "b_param[owner_email]", with: owner_email

        # Lengthens the wait rather than skipping it, leaving time to look at the button
        # while it's pending. The flag is what finds that window: Turbo re-enables the
        # button as the failed submission ends, so an earlier poll reads the wrong state
        page.execute_script(<<~JS)
          const form = document.querySelector("[data-controller~='register--retry']")
          form.setAttribute("data-register--retry-delay-value", "3000")
          form.addEventListener("turbo:submit-end", () => { window.submitEnded = true })
        JS
        click_button "Next"

        # Without the hold a rider could click through the wait, submitting the step twice
        wait_for { page.evaluate_script("window.submitEnded") }
        expect(page).to have_button("Next", disabled: true)

        # The rider never sees the failure, only the retry - waited out past Capybara's default
        wait_for_details_step(wait: 10)

        fill_in "bike[user_name]", with: user_name
        type_into("#bike_primary_frame_color_id", "Red")
        click_combobox_option("Red")
        fill_in "bike[serial_number]", with: "XYZ 123"
        # A theft, so the report is in the flow too - it waits on the emailed link, which
        # puts it last rather than after this form
        type_into("#bike_status", "Stolen")
        click_combobox_option("Stolen")
        fill_in "bike[phone]", with: "555 000 0000"
        click_button "Next"

        expect(page).to have_content("Battery & charging")
        check "Charge with the manufacturer's charger"
        check "Report a swollen battery"
        click_button "Continue"

        expect(page).to have_content("Campus rules")
        check "Dismount in posted zones"
        click_button "Continue"

        expect(page).to have_content("You're almost done")
        check "I, #{user_name}, agree to comply with all of the rules above."
        click_button "Complete Bike Registration"

        expect(page).to have_css("h1", text: "Progress saved")

        # The emailed link finishes a step like any other, and fails like one
        visit confirmation_link
        click_button "Continue"

        # Confirming proves the address, which leaves the theft it's reporting
        expect(page).to have_content("Report your stolen bike", wait: 10)
        fill_in "report[date]", with: "2026-08-05T14:30"
        fill_in "report[address_record_attributes][street]", with: "278 Broadway"
        fill_in "report[address_record_attributes][city]", with: "New York"
        select state.name, from: "report[address_record_attributes][region_record_id]"
        fill_in "report[address_record_attributes][postal_code]", with: "10007"
        click_button "Complete Bike Registration"

        expect(page).to have_css("h1", text: "is listed as stolen on Bike Index", wait: 10)
        expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
          propulsion_type: "pedal-assist", status: "status_stolen")
        expect(Bike.last.current_stolen_record.street).to eq "278 Broadway"
        # A retry that landed twice would be a second registration, or a second signature
        expect(Bike.count).to eq 1
        expect(RegistrationSequenceAcknowledgment.count).to eq 1

        # Every step of the flow failed, and none of them more than once
        expect(failed_steps).to eq([["/register", "1"], ["/register", "2"],
          ["/register/acknowledge", "3"], ["/register/acknowledge", "4"],
          ["/register/acknowledge", "review"], ["/register/confirm_email", nil],
          ["/register/report", "report"]])
      end
    end
  end
end
