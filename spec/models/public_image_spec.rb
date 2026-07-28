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
    let(:bike) { FactoryBot.create(:bike) }

    context "carrierwave image" do
      let(:public_image) { FactoryBot.create(:public_image, :with_image_file) }

      it "returns the carrierwave version url" do
        expect(public_image.file.attached?).to be_falsey
        expect(public_image.image_url).to eq public_image.image.url
        expect(public_image.image_url(:large)).to eq public_image.image.url(:large)
      end
    end

    context "attached file" do
      let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: bike) }

      it "returns the blob url for a blank or unknown size" do
        expect(public_image.reload.file.attached?).to be_truthy

        expect(public_image.image_url).to eq BlobUrl.for(public_image.file.blob)
        expect(public_image.image_url(:unknown)).to eq public_image.image_url
      end

      it "is what bike#image_url returns" do
        bike.reload.update(thumb_path: public_image.image_url(:small))

        expect(bike.image_url(:large)).to eq public_image.image_url(:large)
        expect(bike.image_url(:large)).to_not eq public_image.image_url
      end
    end
  end

  # Direct uploads land in the bucket before the server sees them, so this is the only
  # thing keeping a registration from publishing a non-image or an enormous one
  describe "file_permitted" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:public_image) { PublicImage.new(imageable: bike, file: blob.signed_id) }
    let(:filename) { "bike.jpg" }
    let(:content_type) { "image/jpeg" }
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("not really an image"),
        filename:, content_type:)
    end

    it "is valid" do
      expect(public_image).to be_valid
    end

    context "a pdf" do
      let(:filename) { "invoice.pdf" }
      let(:content_type) { "application/pdf" }

      it "is invalid" do
        expect(public_image).to_not be_valid
        expect(public_image.errors.full_messages.join).to match(/file.*invalid/i)
      end
    end

    context "over the uploader's size cap" do
      before { blob.update(byte_size: PublicImageUploader::MAX_FILE_SIZE + 1) }

      it "is invalid" do
        expect(public_image).to_not be_valid
      end
    end

    context "a carrierwave image" do
      let(:public_image) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }

      it "skips the validation rather than loading an attachment" do
        expect(public_image.attachment_changes).to be_empty
        expect(public_image).to be_valid
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
