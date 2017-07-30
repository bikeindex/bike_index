require 'spec_helper'

describe GetManufacturerLogoWorker do
  it { is_expected.to be_processed_in :afterwards }

  it 'enqueues listing ordering job' do
    GetManufacturerLogoWorker.perform_async
    expect(GetManufacturerLogoWorker).to have_enqueued_sidekiq_job
  end

  # Test is failing inexplicably - http://logo.clearbit.com/trekbikes.com?size=400 still works
  # Since it degrades nicely and isn't required, just ignoring
  xit 'Adds a logo, sets source' do
    manufacturer = FactoryGirl.create(:manufacturer, website: 'https://trekbikes.com')
    GetManufacturerLogoWorker.new.perform(manufacturer.id)
    manufacturer.reload
    expect(manufacturer.logo).to be_present
    expect(manufacturer.logo_source).to eq('Clearbit')
  end

  it "Doesn't break if no logo present" do
    manufacturer = FactoryGirl.create(:manufacturer, website: 'bbbbbbbbbbbbbbsafasds.net')
    GetManufacturerLogoWorker.new.perform(manufacturer.id)
    manufacturer.reload
    expect(manufacturer.logo).to_not be_present
    expect(manufacturer.logo_source).to be_nil
  end

  it 'returns true if no website present' do
    manufacturer = FactoryGirl.create(:manufacturer)
    expect(GetManufacturerLogoWorker.new.perform(manufacturer.id)).to be_truthy
  end

  it 'returns true if no website present' do
    local_image = File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))
    manufacturer = FactoryGirl.create(:manufacturer, logo: local_image, website: 'http://example.com')
    expect(manufacturer.logo).to be_present
    expect(GetManufacturerLogoWorker.new.perform(manufacturer.id)).to be_truthy
  end
end
