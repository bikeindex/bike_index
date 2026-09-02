require "rails_helper"

RSpec.describe Pages::Registrations::Show::Status::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "with owner (default)" do
    let(:bike) { FactoryBot.create(:bike) }
    it "shows not stolen" do
      render_inline(component)
      expect(page).to have_text("Not stolen")
    end
  end

  context "stolen" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    it "shows stolen" do
      render_inline(component)
      expect(page).to have_text("Stolen")
    end
  end

  context "unregistered" do
    let(:bike) { FactoryBot.create(:bike, status: "unregistered_parking_notification") }
    it "shows unregistered in a warning (yellow) badge" do
      render_inline(component)
      expect(page).to have_text("Unregistered")
      expect(page).to have_css("span.tw\\:text-amber-700")
    end
  end

  # Impounded and found (an impounded bike with a "found" impound record) need an
  # organization + impound record to set the status; those are covered end-to-end
  # in spec/requests/registrations/show_request_spec.rb.
end
