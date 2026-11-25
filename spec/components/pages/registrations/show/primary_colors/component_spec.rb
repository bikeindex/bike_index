require "rails_helper"

RSpec.describe Pages::Registrations::Show::PrimaryColors::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "one color" do
    let(:bike) { FactoryBot.create(:bike, primary_frame_color: FactoryBot.create(:color, name: "Blue")) }
    it "renders the singular label and the color" do
      render_inline(component)
      expect(page).to have_text("Primary color")
      expect(page).not_to have_text("Primary colors")
      expect(page).to have_text("Blue")
    end
  end

  context "multiple colors" do
    let(:bike) do
      FactoryBot.create(:bike, primary_frame_color: FactoryBot.create(:color, name: "Blue"),
        secondary_frame_color: FactoryBot.create(:color, name: "Green"))
    end
    it "renders the plural label and joins the colors with and" do
      render_inline(component)
      expect(page).to have_text("Primary colors")
      expect(page).to have_text("Blue")
      expect(page).to have_text("and")
      expect(page).to have_text("Green")
    end
  end

  context "no colors" do
    let(:bike) { FactoryBot.build(:bike, primary_frame_color: nil, secondary_frame_color: nil, tertiary_frame_color: nil) }
    it "renders nothing" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
