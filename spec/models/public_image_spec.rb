require "rails_helper"

RSpec.describe PublicImage, type: :model do
  describe "default_name" do
    it "sets a default name from filename if not bike" do
      public_image = PublicImage.new
      allow(public_image).to receive(:imageable_type).and_return("Nope")
      allow(public_image).to receive(:name).and_return("Boop")
      public_image.default_name
      expect(public_image.name).to eq("Boop")
    end

    it "returns the name of the manufacturer if it isn't other" do
      public_image = PublicImage.new
      bike = FactoryBot.create(:bike, year: 1969, frame_model: "Hobo")
      allow(public_image).to receive(:imageable_type).and_return("Bike")
      allow(public_image).to receive(:imageable).and_return(bike)
      public_image.default_name
      expect(public_image.name).to eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
    end
  end

  describe "large images that exceed the size restriction" do
    before { ImageUploader.enable_processing = true }
    after { ImageUploader.enable_processing = false }

    it "are not created" do
      large_image = File.open(Rails.root.join("spec", "fixtures", "hugeimg.png"))
      public_image = FactoryBot.build(:public_image, image: large_image)
      expect(public_image.save).to eq(false)
      expect(public_image.id).to be_nil
      # Because updated versions of imagemagick respond with different errors
      error_msg = public_image.errors.full_messages.to_sentence
      expect(error_msg).to match(/(too large)|(width exceeds)|(failed to manipulate)/i)
      large_image.close()
    end
  end

  describe "enqueue_after_commit_jobs" do
    context "non-bike" do
      let(:public_image) { PublicImage.new(imageable_type: "Blog", imageable_id: 12) }
      it "does not enqueue after_bike_save_worker" do
        expect do
          public_image.enqueue_after_commit_jobs
        end.to change(AfterBikeSaveWorker.jobs, :size).by(0)
      end
    end
    context "bike" do
      let(:public_image) { PublicImage.new(imageable_type: "Bike", imageable_id: 12) }
      it "enqueues after_bike_save_worker" do
        expect do
          expect do
            public_image.enqueue_after_commit_jobs
          end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
        end.to_not change(ExternalImageUrlStoreWorker.jobs, :size)
      end
    end
    context "remote_image_url" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png") }
      it "enqueues, not after_bike_save_worker" do
        expect do
          expect(public_image.save).to be_truthy
        end.to change(ExternalImageUrlStoreWorker.jobs, :size).by(1)
      end
      context "image present" do
        let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png", image: File.open(Rails.root.join("spec", "fixtures", "bike.jpg"))) }
        it "enqueues after_bike_save_worker" do
          expect do
            expect do
              expect(public_image.save).to be_truthy
            end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
          end.to_not change(ExternalImageUrlStoreWorker.jobs, :size)
        end
      end
    end
  end
end
