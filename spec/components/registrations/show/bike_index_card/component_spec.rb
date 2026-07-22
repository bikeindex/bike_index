require "rails_helper"

RSpec.describe Registrations::Show::BikeIndexCard::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, frame_material: "steel", primary_frame_color: FactoryBot.create(:color, name: "Blue")) }
  let(:component) { described_class.new(bike:, term: :below) }

  it "renders the card header and the summary rows" do
    render_inline(component)
    expect(page).to have_text("This #{bike.type} on Bike Index")
    expect(page).to have_text("Primary color")
    expect(page).to have_text("Blue")
    expect(page).to have_text("Frame material")
    expect(page).to have_text("Registered since")
  end
end
