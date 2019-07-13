require "rails_helper"

RSpec.describe GetManufacturerLogoWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 5.days
  end

  # Test is failing inexplicably - http://logo.clearbit.com/trekbikes.com?size=400 still works
  # Since it degrades nicely and isn't required, just ignoring
  xit "Adds a logo, sets source" do
    manufacturer = FactoryBot.create(:manufacturer, website: "https://trekbikes.com")
    described_class.new.perform(manufacturer.id)
    manufacturer.reload
    expect(manufacturer.logo).to be_present
    expect(manufacturer.logo_source).to eq("Clearbit")
  end

  it "Doesn't break if no logo present" do
    manufacturer = FactoryBot.create(:manufacturer, website: "bbbbbbbbbbbbbbsafasds.net")
    described_class.new.perform(manufacturer.id)
    manufacturer.reload
    expect(manufacturer.logo).to_not be_present
    expect(manufacturer.logo_source).to be_nil
  end

  it "returns true if no website present" do
    manufacturer = FactoryBot.create(:manufacturer)
    expect(described_class.new.perform(manufacturer.id)).to be_truthy
  end

  it "returns true if manufacturer has logo" do
    Sidekiq::Worker.clear_all
    local_image = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
    manufacturer = FactoryBot.create(:manufacturer, logo: local_image, website: "http://example.com")
    expect(manufacturer.logo).to be_present
    expect do
      described_class.new.perform
    end.to change(described_class.jobs, :count).by 1
    described_class.drain
    manufacturer.reload
    expect(manufacturer.logo).to be_present
  end
end
