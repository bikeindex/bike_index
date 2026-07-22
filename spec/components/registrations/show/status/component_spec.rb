require "rails_helper"

RSpec.describe Registrations::Show::Status::Component, type: :component do
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

  # Impounded and found (an impounded bike with a "found" impound record) need an
  # organization + impound record to set the status; those are covered end-to-end
  # in spec/requests/registrations/show_request_spec.rb.
end
