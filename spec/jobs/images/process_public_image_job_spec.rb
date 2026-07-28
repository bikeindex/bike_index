require "rails_helper"

RSpec.describe Images::ProcessPublicImageJob, type: :job do
  let(:instance) { described_class.new }
  let(:bike) { FactoryBot.create(:bike) }
  # Carries GPS EXIF and an orientation tag, which is the whole reason the job exists
  let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: bike, image_path:) }
  let(:image_path) { "spec/fixtures/exif_orientation.jpg" }
  let(:blob) { public_image.reload.file.blob }

  # Tags that identify the photographer, their camera or where they stood
  let(:identifying) { /gps|make|model|serial|lens|software|datetime|makernote/i }
  # Dimensions are autorotated - the orientation tag claimed 1173x1071
  let(:target_metadata) do
    {"identified" => true, "stripped" => true, "width" => 1071, "height" => 1173,
     "analyzed" => true, "processed" => true}
  end

  def exif_fields(data)
    Vips::Image.new_from_buffer(data, "").get_fields.grep(/exif|gps/i)
  end

  it "strips exif, generates the variants and marks the blob" do
    expect(exif_fields(File.binread(Rails.root.join(image_path)))).to be_present
    expect(public_image.file_needs_processing?).to be_truthy
    original_key, original_checksum = blob.key, blob.checksum

    instance.perform(public_image.id)

    expect(blob.reload.metadata).to eq target_metadata
    stripped_data = blob.download
    expect(exif_fields(stripped_data)).to be_empty
    # Only heic is converted - jpeg is served as-is
    expect(blob.content_type).to eq "image/jpeg"
    expect(blob.filename.to_s).to eq "exif_orientation.jpg"
    # Rewritten in place so variant keys and CDN urls stay stable
    expect(blob.key).to eq original_key
    expect(blob.checksum).to_not eq original_checksum
    expect(blob.byte_size).to eq stripped_data.bytesize

    PublicImage::VARIANTS.each_key do |size|
      expect(blob.service.exist?(public_image.file.variant(size).key)).to be_truthy
    end
  end

  it "does not rewrite an already stripped blob, or a record without a file" do
    instance.perform(public_image.id)

    expect { instance.perform(public_image.id) }.to_not change { blob.reload.checksum }
    expect { instance.perform(FactoryBot.create(:public_image, imageable: bike).id) }.to_not raise_error
  end

  it "finishes the variants on a retry, without re-encoding the original" do
    instance.perform(public_image.id)
    variant_key = public_image.file.variant(:small).key
    # Stand in for dying between the strip and the variants
    blob.service.delete(variant_key)
    blob.update!(metadata: blob.metadata.except("processed"))
    expect(public_image.reload.file_needs_processing?).to be_truthy

    expect { instance.perform(public_image.id) }.to_not change { blob.reload.checksum }

    expect(blob.service.exist?(variant_key)).to be_truthy
    expect(blob.metadata).to eq target_metadata
    expect(public_image.reload.file_needs_processing?).to be_falsey
  end

  # Recorded against the real bikeindex-dev R2 bucket; re-record with R2_DEV_* from .env.development
  context "iphone heic on R2", vcr: {cassette_name: "process_public_image_job-heic_r2", preserve_exact_body_bytes: true} do
    let(:image_path) { "spec/fixtures/bike_photo-gps.heic" }
    let(:public_image) { FactoryBot.create(:public_image, imageable: bike, file: r2_blob) }
    let(:target_metadata) do
      {"identified" => true, "stripped" => true, "width" => 2400, "height" => 1800,
       "analyzed" => true, "processed" => true}
    end
    # Fixed key - blob keys are random, and the cassette matches on path (the variant keys hang
    # off it too), so a generated one would never replay
    let(:r2_blob) do
      ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join(image_path)),
        filename: "bike_photo-gps.heic", key: "spec-process-public-image-heic", service_name: :cloudflare_dev)
    end

    it "converts to webp and strips exif from the original and from every variant" do
      source_fields = exif_fields(File.binread(Rails.root.join(image_path)))
      expect(source_fields.grep(identifying).count).to eq 25 # 15 of them GPS, down to the bearing
      expect(blob.service_name).to eq "cloudflare_dev"
      expect(blob.content_type).to eq "image/heic"

      instance.perform(public_image.id)

      expect(blob.reload.metadata).to eq target_metadata
      # Rewritten as webp - only Safari renders heic, and the original is served directly
      expect(blob.content_type).to eq "image/webp"
      expect(blob.filename.to_s).to eq "bike_photo-gps.webp"
      original_data = blob.download
      expect(Vips::Image.new_from_buffer(original_data, "").get("vips-loader")).to start_with "webpload"
      expect(exif_fields(original_data)).to be_empty

      # vips copies exif through a transform - a variant is only clean because the original was
      # rewritten first. It re-synthesizes orientation/resolution/colorspace, so expect those.
      PublicImage::VARIANTS.each_key do |size|
        variant_fields = exif_fields(public_image.file.variant(size).download)
        expect(variant_fields.grep(identifying)).to be_empty
        expect(variant_fields).to include("exif-ifd0-Orientation")
      end
    end
  end

  it "enqueues for an attached file, not for carrierwave" do
    expect {
      FactoryBot.create(:public_image, :with_attached_file, imageable: bike)
    }.to change(described_class.jobs, :size).by(1)
    # AnalyzeJob would merge into the same metadata column from a stale read, dropping the flags
    expect(Sidekiq::ActiveJob::Wrapper.jobs).to be_empty

    expect {
      FactoryBot.create(:public_image, :with_image_file, imageable: bike)
    }.to_not change(described_class.jobs, :size)
  end
end
