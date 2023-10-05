require "rails_helper"

RSpec.describe UpdateManufacturerLogoAndPriorityWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 2.days
  end

  it "Adds a logo, sets source" do
    VCR.use_cassette("get_manufacturer_logo_worker", re_record_interval: 1.month) do
      manufacturer = FactoryBot.create(:manufacturer, website: "https://trekbikes.com")
      described_class.new.perform(manufacturer.id)
      manufacturer.reload
      expect(manufacturer.logo).to be_present
      expect(manufacturer.logo_source).to eq("Clearbit")
    end
  end

  it "Doesn't break if no logo present" do
    VCR.use_cassette("get_manufacturer_logo_worker-nologo", re_record_interval: 1.month) do
      manufacturer = FactoryBot.create(:manufacturer, website: "bbbbbbbbbbbbbbsafasds.net")
      described_class.new.perform(manufacturer.id)
      manufacturer.reload
      expect(manufacturer.logo).to_not be_present
      expect(manufacturer.logo_source).to be_nil
    end
  end

  it "updates manufacturer priority" do
    manufacturer = FactoryBot.create(:manufacturer)
    manufacturer.update_column :priority, 14
    described_class.new.perform(manufacturer.id)
    expect(manufacturer.reload.priority).to eq 0
  end

  context "manufacturer has logo" do
    it "no-ops" do
      local_image = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
      manufacturer = FactoryBot.create(:manufacturer, logo: local_image, website: "http://example.com")
      expect(manufacturer.logo).to be_present
      Sidekiq::Worker.clear_all
      described_class.new.perform
      # Verify that it doesn't call update
      expect_any_instance_of(Manufacturer).to_not receive(:update)
      described_class.drain
      manufacturer.reload
      expect(manufacturer.logo).to be_present
    end
  end
end
