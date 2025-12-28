require "rails_helper"

RSpec.describe Images::ExternalUrlStoreJob, type: :job do
  let(:instance) { described_class.new }

  context "valid performance" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:is_private) { false }
    let(:public_image) do
      # Use the email logo url - since that file it should never be removed
      PublicImage.create(imageable: bike, is_private:,
        external_image_url: "https://files.bikeindex.org/email_assets/logo.png")
    end
    it "downloads and processes the image" do
      expect(public_image.id).to be_present
      Sidekiq::Job.clear_all
      expect(public_image.image).to_not be_present
      VCR.use_cassette("external_image_url_store_worker") do
        instance.perform(public_image.id)
        public_image.reload
        expect(public_image.image).to be_present
      end
      expect(Sidekiq::Job.jobs.count).to eq 1
      expect(CallbackJob::AfterBikeSaveJob).to have_enqueued_sidekiq_job(bike.id, false, true)
    end
    context "is_private true" do
      let(:is_private) { true }
      it "downloads and processes" do
        expect(public_image.id).to be_present
        Sidekiq::Job.clear_all
        expect(public_image.image).to_not be_present
        VCR.use_cassette("external_image_url_store_worker") do
          instance.perform(public_image.id)
          public_image.reload
          expect(public_image.image).to be_present
        end
        expect(Sidekiq::Job.jobs.count).to eq 1
        expect(CallbackJob::AfterBikeSaveJob).to have_enqueued_sidekiq_job(bike.id, false, true)
      end
    end
  end
  context "already has an image" do
    let(:public_image) { FactoryBot.create(:public_image, external_image_url: "https://files.bikeindex.org/email_assets/logo.png") }
    it "doesn't do anything" do
      expect(public_image.image).to be_present
      expect_any_instance_of(PublicImage).to_not receive(:save)
      instance.perform(public_image.id)
    end
  end
end
