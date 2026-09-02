require "rails_helper"

RSpec.describe Pages::Registrations::Show::BikeDetails::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, frame_model: "Rocket", frame_material: "steel") }
  let(:component) { described_class.new(bike:, serial_user: nil) }

  it "renders the card with the serial and spec rows" do
    render_inline(component)
    expect(page).to have_text("#{bike.type_titleize} details")
    expect(page).to have_text("Serial")
    expect(page).to have_text(bike.serial_number.upcase)
    expect(page).to have_text("Manufacturer")
    expect(page).to have_text(bike.manufacturer.name)
    expect(page).to have_text("Rocket")
  end

  context "non-standard vehicle" do
    let(:bike) { FactoryBot.create(:bike, cycle_type: :cargo) }
    it "shows the vehicle type" do
      render_inline(component)
      expect(page).to have_text("Vehicle type")
      expect(page).to have_text(bike.cycle_type_name)
    end
  end

  context "hidden serial rendered for the public (nil user)" do
    let(:bike) { FactoryBot.create(:impound_record).bike.reload }
    it "shows hidden rather than the serial" do
      expect(bike.serial_hidden?).to be_truthy
      render_inline(component)
      expect(page).to have_text("hidden")
      expect(page).not_to have_text(bike.serial_number.upcase)
    end
  end
end
