require "spec_helper"

describe PublicImage do
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

  describe "lottapixel" do
    it "doesn't break" do
      lottapixel = File.open(File.join(Rails.root, "spec", "fixtures", "hugeimg.png"))
      public_image = FactoryBot.build(:public_image, image: lottapixel)
      public_image.save
      expect(public_image.id).to be_nil
      # Because updated versions of imagemagick respond with different errors
      error_msg = public_image.errors.full_messages.to_s
      expect(error_msg).to match(/(too large)|(width exceeds)/)
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
        # TODO: Rails 5 update - after commit doesn't run :(
        expect(public_image.save).to be_truthy
        expect do
          public_image.enqueue_after_commit_jobs
        end.to change(ExternalImageUrlStoreWorker.jobs, :size).by(1)
      end
      context "image present" do
        let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png", image: File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))) }
        it "enqueues after_bike_save_worker" do
          # TODO: Rails 5 update - after commit doesn't run :(
          expect(public_image.save).to be_truthy
          expect do
            expect do
              public_image.enqueue_after_commit_jobs
            end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
          end.to_not change(ExternalImageUrlStoreWorker.jobs, :size)
        end
      end
    end
  end
end
