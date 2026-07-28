require "rails_helper"

RSpec.describe PublicImage, type: :model do
  describe "default_name" do
    it "sets a default name from filename if not bike" do
      public_image = PublicImage.new
      allow(public_image).to receive(:imageable_type).and_return("Nope")
      allow(public_image).to receive(:name).and_return("Boop")
      public_image.default_name
      expect(public_image.name).to eq("Boop")
      expect(public_image.bike_type).to be_blank
    end

    it "returns the name of the manufacturer if it isn't other" do
      bike = FactoryBot.create(:bike, year: 1969, frame_model: "Hobo", cycle_type: "tandem")
      public_image = PublicImage.new(imageable: bike)
      public_image.default_name
      expect(public_image.name).to eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
      expect(public_image.bike_type).to eq "tandem"
    end
  end

  describe "process_image_upload" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:image_file) { File.open(Rails.root.join("spec", "fixtures", "bike.jpg")) }

    context "local file storage (sandbox/dev)" do
      it "generates versions inline and does not enqueue the background job" do
        expect(PublicImageUploader.storage).to eq CarrierWave::Storage::File
        PublicImageUploader.enable_processing = true
        public_image = nil
        expect do
          public_image = PublicImage.create!(imageable: bike, image: image_file)
        end.to change(CarrierWaveProcessJob.jobs, :size).by(0)
        expect(public_image.process_image_upload).to be_truthy
        expect(File.exist?(public_image.image.small.path)).to be_truthy
      ensure
        PublicImageUploader.enable_processing = false
        public_image&.image&.remove!
        image_file.close
      end
    end

    context "fog storage (production)" do
      let(:public_image) { PublicImage.new(imageable: bike, image: image_file) }
      before { allow(public_image).to receive(:remote_storage?).and_return(true) }
      it "defers version generation to the background job" do
        expect do
          public_image.save!
        end.to change(CarrierWaveProcessJob.jobs, :size).by(1)
        expect(public_image.process_image_upload).to be_nil
        image_file.close
      end
    end
  end

  describe "image_url" do
    context "carrierwave image" do
      let(:public_image) { FactoryBot.create(:public_image, :with_image_file) }

      it "returns the carrierwave version url" do
        expect(public_image.file.attached?).to be_falsey
        expect(public_image.image_url).to eq public_image.image.url
        expect(public_image.image_url(:large)).to eq public_image.image.url(:large)
      end
    end

    context "attached file" do
      let(:public_image) { FactoryBot.create(:public_image, :with_attached_file) }

      it "returns a variant url per size, and the blob for a blank or unknown one" do
        expect(public_image.reload.file.attached?).to be_truthy

        expect(public_image.image_url).to eq BlobUrl.for(public_image.file.blob)
        expect(public_image.image_url(:unknown)).to eq public_image.image_url
        # Strings resolve too - named variants are looked up by symbol
        expect(public_image.image_url("large")).to eq public_image.image_url(:large)
        expect(public_image.image_url(:large)).to_not eq public_image.image_url
      end
    end
  end

  describe "open_file" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(Rails.root.join("spec", "fixtures", "bike.jpg"))) }

    it "opens the local file" do
      expect(public_image.local_file?).to be_truthy
      file = public_image.open_file
      expect(file).to be_present
      file.close
    end

    context "local file missing on disk" do
      it "returns nil" do
        expect(public_image.local_file?).to be_truthy
        FileUtils.rm(public_image.image.path)
        expect(public_image.open_file).to be_nil
      end
    end

    context "attached file" do
      let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: bike) }

      it "returns a readable file on disk that outlives the method" do
        file = public_image.reload.open_file
        # blob.open would have unlinked by now - image processors need a path, not a StringIO
        expect(File.exist?(file.path)).to be_truthy
        expect(Vips::Image.new_from_file(file.path).width).to be > 0
        file.close!
      end

      it "returns nil when the blob is missing from the service" do
        public_image.file.blob.service.delete(public_image.file.blob.key)

        expect(public_image.open_file).to be_nil
      end
    end
  end

  describe "enqueue_after_commit_jobs" do
    context "non-bike" do
      let(:public_image) { PublicImage.new(imageable_type: "Blog", imageable_id: 12) }
      it "does not enqueue after_bike_save_worker" do
        expect {
          public_image.enqueue_after_commit_jobs
        }.to change(CallbackJobs::AfterBikeSaveJob.jobs, :size).by(0)
      end
    end
    context "bike" do
      let(:public_image) { PublicImage.new(imageable_type: "Bike", imageable_id: 12) }
      it "enqueues after_bike_save_worker" do
        expect {
          expect {
            public_image.enqueue_after_commit_jobs
          }.to change(CallbackJobs::AfterBikeSaveJob.jobs, :size).by(1)
        }.to_not change(Images::ExternalUrlStoreJob.jobs, :size)
      end
    end
    context "remote_image_url" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png") }
      it "enqueues, not after_bike_save_worker" do
        bike.destroy
        expect(bike.cycle_type).to eq "bike"
        expect(public_image.bike_type).to eq "bike"
        expect {
          expect(public_image.save).to be_truthy
        }.to change(Images::ExternalUrlStoreJob.jobs, :size).by(1)
      end
      context "image present" do
        let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png", image: File.open(Rails.root.join("spec", "fixtures", "bike.jpg"))) }
        it "enqueues after_bike_save_worker" do
          expect {
            expect {
              expect(public_image.save).to be_truthy
            }.to change(CallbackJobs::AfterBikeSaveJob.jobs, :size).by(1)
          }.to_not change(Images::ExternalUrlStoreJob.jobs, :size)
        end
      end
    end
  end
end
