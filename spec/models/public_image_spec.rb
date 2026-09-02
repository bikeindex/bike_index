require "rails_helper"
require "image_processing/vips" # For the unsharpened baseline

RSpec.describe PublicImage, type: :model do
  describe "default_name" do
    let(:organization) { FactoryBot.create(:organization) }

    it "is the bike title and its colors" do
      bike = FactoryBot.create(:bike, year: 1969, frame_model: "Hobo", cycle_type: "tandem")
      public_image = FactoryBot.create(:public_image, imageable: bike)
      expect(public_image.name).to eq("#{bike.title_string} #{bike.frame_colors.to_sentence}")
      expect(public_image.bike_type).to eq "tandem"
    end

    it "is the carrierwave filename for an imageable that isn't a bike" do
      public_image = FactoryBot.create(:public_image, :with_image_file, imageable: organization)
      expect(public_image.name).to eq "Bike Photo Landscape"
      expect(public_image.bike_type).to be_blank
    end

    it "is the attached filename for an imageable that isn't a bike" do
      public_image = FactoryBot.create(:public_image, :with_attached_file, imageable: organization)
      expect(public_image.name).to eq "Bike Photo Landscape"
    end

    it "is blank without a file" do
      expect(PublicImage.new(imageable: organization).default_name).to eq ""
    end
  end

  describe "imageable_name" do
    it "is nil without an imageable" do
      expect(PublicImage.new.imageable_name).to be_nil
    end

    it "is the bike display_name" do
      bike = FactoryBot.create(:bike)
      expect(PublicImage.new(imageable: bike).imageable_name).to eq bike.display_name
    end

    it "is the blog title" do
      blog = FactoryBot.create(:blog, title: "Some blog post")
      expect(PublicImage.new(imageable: blog).imageable_name).to eq "Some blog post"
    end

    it "is the organization name" do
      organization = FactoryBot.create(:organization, name: "Cool Bike Shop")
      expect(PublicImage.new(imageable: organization).imageable_name).to eq "Cool Bike Shop"
    end

    it "is nil for imageables that don't name themselves" do
      expect(PublicImage.new(imageable: FactoryBot.create(:social_post)).imageable_name).to be_nil
    end
  end

  describe "image_alt" do
    it "is the bike title alone - the name is already the bike" do
      bike = FactoryBot.create(:bike, year: 1969, frame_model: "Hobo", cycle_type: "tandem")
      public_image = FactoryBot.create(:public_image, imageable: bike)
      expect(public_image.image_alt).to eq "#{bike.title_string} #{bike.frame_colors.to_sentence}"
    end

    it "adds what it's from when the name is only a filename" do
      organization = FactoryBot.create(:organization, name: "Cool Bike Shop")
      public_image = FactoryBot.create(:public_image, :with_attached_file, imageable: organization)
      expect(public_image.image_alt).to eq "Bike Photo Landscape - Cool Bike Shop"
    end

    it "is the name alone for an imageable that doesn't name itself" do
      public_image = FactoryBot.create(:public_image, :with_attached_file, imageable: FactoryBot.create(:social_post))
      expect(public_image.image_alt).to eq "Bike Photo Landscape"
    end

    it "is blank with nothing to go on" do
      expect(PublicImage.new.image_alt).to eq ""
    end
  end

  describe "image_size" do
    it "is nil without an image" do
      expect(PublicImage.new.image_size).to be_nil
    end

    it "is the carrierwave file size" do
      public_image = FactoryBot.create(:public_image, :with_image_file)
      expect(public_image.image_size).to eq public_image.image.size
      expect(public_image.image_size).to be > 0
    end

    it "is the blob byte_size when attached" do
      public_image = FactoryBot.create(:public_image, :with_attached_file)
      expect(public_image.reload.image_size).to eq public_image.file.blob.byte_size
    end
  end

  # ApplicationUploader#blank? answers from the retrieved file rather than asking storage,
  # which with fog is a HEAD request on every render and every validation
  describe "image?" do
    it "is false without an image" do
      expect(PublicImage.new.image?).to be_falsey
    end

    it "is true for a stored carrierwave image, reloaded" do
      public_image = FactoryBot.create(:public_image, :with_image_file)
      expect(public_image.reload.image?).to be_truthy
    end

    it "is true for a cached image, before storing" do
      public_image = PublicImage.new(image: File.open(Rails.root.join("spec", "fixtures", "bike.jpg")))
      expect(public_image.image?).to be_truthy
    end
  end

  describe "image_present?" do
    it "is true for an activestorage row, which image? says no to" do
      public_image = FactoryBot.create(:public_image, :with_attached_file).reload
      expect(public_image.image?).to be_falsey
      expect(public_image.image_present?).to be_truthy
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

  describe "activestorage" do
    let!(:carrierwave) { FactoryBot.create(:public_image, :with_image_file) }
    let!(:attached) { FactoryBot.create(:public_image, :with_attached_file) }

    it "is the rows image_url dispatches to the new backend" do
      expect(carrierwave.activestorage?).to be_falsey
      expect(carrierwave.carrierwave?).to be_truthy
      expect(attached.reload.activestorage?).to be_truthy
      expect(attached.carrierwave?).to be_falsey

      expect(PublicImage.activestorage.pluck(:id)).to eq([attached.id])
      expect(PublicImage.carrierwave.pluck(:id)).to eq([carrierwave.id])
      # Complements, so the pair tracks the migration without double-counting
      expect(PublicImage.activestorage.count + PublicImage.carrierwave.count).to eq PublicImage.count
    end

    context "a row holding both" do
      let!(:attached) do
        FactoryBot.create(:public_image, :with_attached_file)
          .tap { it.update!(image: File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
      end

      it "is activestorage - the attachment supersedes the carrierwave version" do
        expect(attached.reload.image).to be_present
        expect(attached.activestorage?).to be_truthy
        expect(attached.image_url).to_not eq attached.image.url
        expect(attached.image_url).to eq BlobUrl.for(attached.file.blob)
        expect(PublicImage.activestorage.pluck(:id)).to include attached.id
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

  describe "variants" do
    let(:image_path) { "spec/fixtures/bike_photo-landscape.jpeg" }
    let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, image_path:) }
    # What the variant does, minus the sharpening mask trailing its dimensions
    let(:unsharpened) do
      ImageProcessing::Vips.source(Rails.root.join(image_path))
        .resize_to_fit(*PublicImage::VARIANTS[:medium][:resize_to_fit].first(2))
        .convert("webp").call.read
    end

    # image_processing 2.0 turned vips sharpening after resize off by default, softening every
    # variant. The mask is worth ~36% of the edge energy
    it "sharpens after the resize" do
      expect(edge_energy(public_image.file.variant(:medium).processed.download))
        .to be > edge_energy(unsharpened) * 1.2
    end
  end

  # Direct uploads land in the bucket before the server sees them, so this is all that keeps
  # a registration from publishing a non-image or an enormous one
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

    # Permitted here but absent from carrierwave's whitelist, which alone would reject it
    context "heic" do
      let(:filename) { "bike.heic" }
      let(:content_type) { "image/heic" }

      it "is valid" do
        expect(public_image).to be_valid
      end
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

    # Created from the client's JSON, then PUT straight to the bucket - so content_type is
    # whatever the client typed until we look at the bytes
    context "a direct upload" do
      let(:data) { File.binread(Rails.root.join("spec/fixtures/bike.jpg")) }
      let(:blob) do
        ActiveStorage::Blob.create_before_direct_upload!(filename:, content_type:,
          byte_size: data.bytesize, checksum: Digest::MD5.base64digest(data))
          .tap { it.service.upload(it.key, StringIO.new(data), checksum: it.checksum) }
      end

      it "is valid" do
        expect(public_image).to be_valid
      end

      context "claiming a permitted type for bytes that aren't one" do
        let(:data) { "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n%%EOF\n" }

        it "is invalid" do
          expect(blob.content_type).to eq "image/jpeg" # what the client claimed
          expect(public_image).to_not be_valid
          expect(public_image.file.blob.content_type).to eq "application/pdf" # what it really is
        end
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
        }.to_not change(ImageJobs::ExternalUrlStoreJob.jobs, :size)
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
        }.to change(ImageJobs::ExternalUrlStoreJob.jobs, :size).by(1)
      end
      context "image present" do
        let(:public_image) { PublicImage.new(imageable: bike, external_image_url: "http://example.com/image.png", image: File.open(Rails.root.join("spec", "fixtures", "bike.jpg"))) }
        it "enqueues after_bike_save_worker" do
          expect {
            expect {
              expect(public_image.save).to be_truthy
            }.to change(CallbackJobs::AfterBikeSaveJob.jobs, :size).by(1)
          }.to_not change(ImageJobs::ExternalUrlStoreJob.jobs, :size)
        end
      end
    end
  end
end
