require "rails_helper"

RSpec.describe Pages::Registrations::Show::Subtitle::Component, type: :component do
  let(:color) { FactoryBot.create(:color, name: "Blue") }
  let(:bike) { FactoryBot.create(:bike, year: 2020, frame_model: "Rocket", primary_frame_color: color) }
  let(:component) { described_class.new(bike:) }

  it "combines year and model with the colors" do
    render_inline(component)
    expect(page).to have_text("2020")
    expect(page).to have_text("Rocket")
    expect(page).to have_text("Blue")
  end
end
