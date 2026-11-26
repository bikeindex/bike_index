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
    expect(page).to have_no_link(href: /bikebook/)
  end

  context "registered as a Bike Book model" do
    let(:bike) { FactoryBot.create(:bike, year: 2025, frame_model: "Haul ST") }
    let(:bikebook_model) do
      BikebookModel.create!(catalog_id: "m/specialized/2025/haul-st", manufacturer: bike.manufacturer,
        name: "Haul ST", model_slug: "haul-st", first_year: 2025)
    end

    before { VehicleSpecification.create!(bike_obj: bike, bikebook_model:) }

    it "links to its page, last" do
      render_inline(component)
      expect(page).to have_css("dl > div:last-child a[href='/bikebook?vehicle_models=m/specialized/2025/haul-st']",
        text: "View stock bike on Bike Book")
    end

    context "the catalog has dropped" do
      before { bikebook_model.destroy }

      it "doesn't link" do
        render_inline(described_class.new(bike: bike.reload))
        expect(page).to have_no_link(href: /bikebook/)
      end
    end
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
    it "shows hidden rather than the serial, with the reason in a tooltip" do
      expect(bike.serial_hidden?).to be_truthy
      render_inline(component)
      expect(page).to have_text("hidden")
      expect(page).not_to have_text(bike.serial_number.upcase)
      expect(page).to have_css("[role=tooltip]", text: "because bike is found", visible: :all)
    end
  end
end
