# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Edit drivetrain", :js, type: :system do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }

  before do
    FrontGearType.fixed # name "1", standard
    FactoryBot.create(:front_gear_type, name: "3", count: 3, standard: true)
    FactoryBot.create(:front_gear_type, name: "3 internal", count: 3, internal: true)
    FactoryBot.create(:front_gear_type, name: "12 Speed Pinion Gearbox", count: 12, internal: true)
  end

  def within_front_gears(&)
    within(find("label", text: "Front gears").ancestor(".related-fields"), &)
  end

  def select_front_gear(name)
    within_front_gears do
      find(".selectize-input").click
      find(".selectize-dropdown-content .option", text: name).click
    end
  end

  it "locks the internal checkbox for pinion gearboxes and unlocks it otherwise" do
    sign_in_user_and_visit_drivetrain

    select_front_gear("12 Speed Pinion Gearbox")

    internal = find("#front_gear_select_internal")
    expect(internal).to be_checked
    expect(internal).to be_disabled

    select_front_gear("3")

    expect(internal).not_to be_disabled
  end

  context "bike already has a pinion gearbox" do
    let(:pinion) { FrontGearType.find_by(name: "12 Speed Pinion Gearbox") }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:, front_gear_type: pinion) }

    it "renders the internal checkbox checked and disabled" do
      sign_in_user_and_visit_drivetrain

      internal = find("#front_gear_select_internal")
      expect(internal).to be_checked
      expect(internal).to be_disabled
    end
  end

  def sign_in_user_and_visit_drivetrain
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in")

    visit "/bikes/#{bike.id}/edit/drivetrain"
    expect(page).to have_content("Drivetrain")
  end
end
