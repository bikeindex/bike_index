# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepReport::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:status) { "status_stolen" }
  let(:sequence) { nil }
  let(:params) { {bike: {owner_email: current_user.email, manufacturer_id: 12, status:}} }
  let(:b_param) { BParam.create(origin: "register_flow", creator_id: current_user.id, params: params.as_json) }
  let(:steps) { BikeServices::Register.steps(b_param, sequence:) }

  it "asks about the theft, and is the last step" do
    render_inline(described_class.new(b_param:, sequence:, steps:))

    expect(page).to have_field("report[police_report_number]")
    expect(page).to have_button("Complete Bike Registration")
    # When and where are what a theft has to answer, so they open blank and required
    date = page.find("input[name='report[date]'].dateInputUpdateZone")
    expect(date[:value]).to be_blank
    expect(date[:required]).to be_present
    expect(page.find("input[name='report[address_record_attributes][street]']")[:required]).to be_present
    expect(page.find("input[name='report[address_record_attributes][city]']")[:required]).to be_present
    # The rest of it isn't
    expect(page.find("input[name='report[police_report_number]']")[:required]).to be_blank
    expect(page).to have_css("input[name='report[timezone]'].hiddenFieldTimezone", visible: :all)
    # Nothing to report about a vehicle nobody found
    expect(page).to_not have_field("report[impounded_description]")
  end

  # Saved report data, which is what a re-render reads back - not a finished report
  context "with report data" do
    let(:params) do
      super().merge(stolen_record: {date_stolen: "2026-08-05T14:30:00-05:00", street: "1 Main St",
                                    theft_description: "Cut lock", phone_for_users: "0"})
    end

    it "shows the report as it was entered" do
      render_inline(described_class.new(b_param:, sequence:, steps:))

      date = page.find("input[name='report[date]']")
      # The app's zone, which is what a submission without one is read back in
      expect(date[:value]).to eq Time.parse("2026-08-05T19:30:00 UTC").in_time_zone.strftime("%Y-%m-%dT%H:%M")
      # The instant itself, for the localizer to render in the browser's zone
      expect(Time.parse(date["data-initialtime"])).to be_within(1).of Time.parse("2026-08-05T19:30:00 UTC")
      expect(page).to have_field("report[address_record_attributes][street]", with: "1 Main St")
      expect(page).to have_field("report[theft_description]", with: "Cut lock")
      expect(page.find("input[name='report[phone_for_users]'][type='checkbox']")).to_not be_checked
      # Default on, and this report didn't turn it off
      expect(page.find("input[name='report[phone_for_police]'][type='checkbox']")).to be_checked
    end
  end

  context "found" do
    let(:status) { "status_impounded" }

    it "asks about the find instead, in its own words" do
      render_inline(described_class.new(b_param:, sequence:, steps:))

      expect(page).to have_field("report[impounded_description]")
      expect(page).to_not have_field("report[theft_description]")
      expect(page).to_not have_field("report[police_report_number]")
      expect(page).to have_css("label", text: "Address where you found it")
      # When and where are asked of a find as well as a theft
      expect(page.find("input[name='report[date]']")[:required]).to be_present
      expect(page.find("input[name='report[address_record_attributes][street]']")[:required]).to be_present
    end
  end

  context "with acknowledgment pages after it" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:params) do
      {bike: {owner_email: current_user.email, manufacturer_id: 12, status:, cycle_type: "e-scooter",
              creation_organization_id: organization.id}}
    end

    it "doesn't claim to finish the registration" do
      render_inline(described_class.new(b_param:, sequence:, steps:))

      expect(page).to have_button("Next")
      expect(page).to_not have_button("Complete e-Scooter Registration")
    end

    # The emailed link is clicked after the pages, so the report is what's left - the same
    # step list as above, which is why the button reads off what's been agreed to instead
    context "already acknowledged" do
      before { FactoryBot.create(:registration_sequence_acknowledgment, b_param:, registration_sequence: sequence) }

      it "finishes the registration" do
        render_inline(described_class.new(b_param:, sequence:, steps:))

        expect(page).to have_button("Complete e-Scooter Registration")
        expect(page).to_not have_button("Next")
      end
    end
  end
end
