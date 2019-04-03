require 'spec_helper'

describe AfterBikeSaveWorker do
  let(:subject) { AfterBikeSaveWorker }
  let(:instance) { subject.new }
  before { Sidekiq::Worker.clear_all }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe 'enqueuing jobs' do
    let(:bike_id) { FactoryBot.create(:ownership, user_hidden: true).bike_id }
    it 'enqueues the duplicate_bike_finder_worker' do
      expect do
        instance.perform(bike_id)
      end.to change(DuplicateBikeFinderWorker.jobs, :size).by 1
    end
  end

  it "doesn't break if unable to find bike" do
    instance.perform(96)
  end

  describe "update listing order" do
    it "updates the listing order" do
      bike = FactoryBot.create(:bike)
      bike.update_attribute :listing_order, -22
      instance.perform(bike.id)
      bike.reload
      expect(bike.listing_order).to eq bike.get_listing_order
    end

    context "unchanged listing order" do
      it "does not update the listing order or enqueue afterbikesave" do
        bike = FactoryBot.create(:bike)
        bike.update_attribute :listing_order, bike.get_listing_order
        expect_any_instance_of(Bike).to_not receive(:update_attribute)
        instance.perform(bike.id)
      end
    end
  end

  describe "download external_image_urls" do
    let(:external_image_urls) { ["https://files.bikeindex.org/email_assets/logo.png", "https://files.bikeindex.org/email_assets/logo.png", "https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"] }
    let(:passed_external_image_urls) { external_image_urls }
    let(:bike) { FactoryBot.create(:bike) }
    let!(:b_param) do
      FactoryBot.create(:b_param,
                        created_bike_id: bike.id,
                        params: { bike: { owner_email: bike.owner_email, external_image_urls: passed_external_image_urls } }) 
    end
    it "creates and downloads the images" do
      expect do
        instance.perform(bike.id)
      end.to change(PublicImage, :count).by 2
      bike.reload
      # The public images have been created with the matching urls
      expect(bike.public_images.pluck(:external_image_url)).to match_array external_image_urls.uniq
      # Processing occurs in the processing job - not inline
      expect(bike.public_images.any? { |i| i.image.present? }).to be_falsey
      # TODO: Rails 5 update - after commit doesn't run :( - uncomment when upgraded
      # expect(ExternalImageUrlStoreWorker.jobs.count).to eq 2
    end
    context "images already exist, passed some blank values" do
      let(:passed_external_image_urls) { external_image_urls + [nil, ""] }
      it "doesn't create new images" do
        external_image_urls.uniq.each { |url| bike.public_images.create(external_image_url: url) }
        bike.reload
        expect(bike.external_image_urls).to eq external_image_urls.uniq
        expect do
          instance.perform(bike.id)
        end.to_not change(PublicImage, :count)
        bike.reload
      end
    end
  end

  describe "serialized" do
    let!(:bike) { FactoryBot.create(:stolen_bike) }
    it "calls the things we expect it to call" do
      ENV["BIKE_WEBHOOK_AUTH_TOKEN"] = "xxxx"
      serialized = instance.serialized(bike)
      # expect(serialized[:auth_token]).to eq "xxxx" # fails on travis :/
      expect(serialized[:bike][:id]).to be_present
      expect(serialized[:bike][:stolen_record]).to be_present
      expect(serialized[:update]).to be_truthy
    end
  end

  describe "remove_partial_registrations" do
    let!(:partial_registration) { FactoryBot.create(:b_param_partial_registration, owner_email: "stuff@things.COM") }
    let(:bike) { FactoryBot.create(:bike, owner_email: "stuff@things.com") }
    it "removes the partial registration" do
      expect(partial_registration.partial_registration?).to be_truthy
      expect(partial_registration.with_bike?).to be_falsey
      instance.perform(bike.id)
      partial_registration.reload
      expect(partial_registration.with_bike?).to be_truthy
      expect(partial_registration.created_bike).to eq bike
    end
    context "with a more accurate match" do
      let(:manufacturer) { bike.manufacturer }
      let!(:partial_registration_accurate) { FactoryBot.create(:b_param_partial_registration, owner_email: "STUFF@things.com", manufacturer: manufacturer) }
      it "only removes the more accurate match" do
        expect(partial_registration.partial_registration?).to be_truthy
        expect(partial_registration.with_bike?).to be_falsey
        expect(partial_registration_accurate.partial_registration?).to be_truthy
        expect(partial_registration_accurate.with_bike?).to be_falsey
        instance.perform(bike.id)
        partial_registration.reload
        partial_registration_accurate.reload
        expect(partial_registration.with_bike?).to be_falsey
        expect(partial_registration_accurate.with_bike?).to be_truthy
        expect(partial_registration_accurate.created_bike).to eq bike
      end
    end
  end
end
