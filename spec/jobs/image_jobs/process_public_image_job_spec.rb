require "rails_helper"

RSpec.describe ImageJobs::ProcessPublicImageJob, type: :job do
  let(:instance) { described_class.new }
  let(:bike) { FactoryBot.create(:bike) }
  # Carries GPS EXIF and an orientation tag, the whole reason the job exists
  let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: bike, image_path:) }
  let(:image_path) { "spec/fixtures/exif_orientation.jpg" }
  let(:blob) { public_image.reload.file.blob }

  # Tags that identify the photographer, their camera or where they stood
  let(:identifying) { /gps|make|model|serial|lens|software|datetime|makernote/i }
  let(:dimensions) { [1071, 1173] } # Autorotated; the tag claimed 1173x1071
  # Ours, not blob.metadata - a direct upload posts that, so it can't gate the strip
  let(:target_binx_data) { {"stripped" => true, "processed" => true, "bike_id" => bike.id} }

  def exif_fields(data)
    Vips::Image.new_from_buffer(data, "").get_fields.grep(/exif|gps/i)
  end

  def dimensions_of(data)
    image = Vips::Image.new_from_buffer(data, "")
    [image.width, image.height]
  end

  # n-pages counts what the file holds, not what loaded; formats that can't animate omit it
  def frame_count(data)
    image = Vips::Image.new_from_buffer(data, "")
    image.get_typeof("n-pages").zero? ? 1 : image.get("n-pages")
  end

  it "strips exif, generates the variants and marks the blob" do
    expect(exif_fields(File.binread(Rails.root.join(image_path)))).to be_present
    expect(public_image.file_needs_processing?).to be_truthy
    original_key, original_checksum = blob.key, blob.checksum
    blob.update!(binx_data: {"b_param_id" => 42}) # The register direct upload's stamp

    instance.perform(public_image.id)

    expect(blob.reload.binx_data).to eq target_binx_data.merge("b_param_id" => 42)
    stripped_data = blob.download
    expect(dimensions_of(stripped_data)).to eq dimensions
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

  # Rails protects only analyzed/identified/composed, so the rest is the client's to set
  it "still processes an upload that claims to be processed" do
    data = File.binread(Rails.root.join(image_path))
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "gps.jpg",
      content_type: "image/jpeg", byte_size: data.bytesize,
      checksum: Digest::MD5.base64digest(data), metadata: {"processed" => true, "stripped" => true})
    blob.service.upload(blob.key, StringIO.new(data), checksum: blob.checksum)
    public_image = PublicImage.create!(imageable: bike, file: blob.signed_id)

    expect(public_image.file.blob.metadata["processed"]).to be_truthy # the client's claim stuck
    expect(public_image.file_needs_processing?).to be_truthy

    instance.perform(public_image.id)

    expect(exif_fields(public_image.reload.file.blob.download)).to be_empty
  end

  it "does not rewrite an already stripped blob, or a record without a file" do
    instance.perform(public_image.id)

    expect { instance.perform(public_image.id) }.to_not change { blob.reload.checksum }
    expect { instance.perform(FactoryBot.create(:public_image, imageable: bike).id) }.to_not raise_error
  end

  context "animated gif" do
    let(:image_path) { "spec/fixtures/animated.gif" }
    let(:dimensions) { [120, 80] }

    it "keeps every frame through the strip" do
      expect(frame_count(File.binread(Rails.root.join(image_path)))).to eq 4

      instance.perform(public_image.id)

      expect(blob.reload.binx_data).to eq target_binx_data
      expect(blob.content_type).to eq "image/gif"
      expect(frame_count(blob.download)).to eq 4
      # Variants are stills
      expect(frame_count(public_image.file.variant(:small).download)).to eq 1
    end
  end

  context "tiff" do
    let(:image_path) { "spec/fixtures/bike_photo.tif" }
    let(:dimensions) { [800, 600] }

    it "rewrites it as webp" do
      expect(blob.content_type).to eq "image/tiff"

      instance.perform(public_image.id)

      expect(blob.reload.binx_data).to eq target_binx_data
      expect(dimensions_of(blob.download)).to eq dimensions
      expect(blob.content_type).to eq "image/webp"
      expect(blob.filename.to_s).to eq "bike_photo.webp"
      expect(Vips::Image.new_from_buffer(blob.download, "").get("vips-loader")).to start_with "webpload"
    end
  end

  it "finishes the variants on a retry, without re-encoding the original" do
    instance.perform(public_image.id)
    variant_key = public_image.file.variant(:small).key
    # Stand in for dying between the strip and the variants
    blob.service.delete(variant_key)
    blob.update!(binx_data: blob.binx_data.except("processed"))
    expect(public_image.reload.file_needs_processing?).to be_truthy

    expect { instance.perform(public_image.id) }.to_not change { blob.reload.checksum }

    expect(blob.service.exist?(variant_key)).to be_truthy
    expect(blob.binx_data).to eq target_binx_data
    expect(public_image.reload.file_needs_processing?).to be_falsey
  end

  # Recorded against the real bikeindex-test bucket; re-record with R2_TEST_* from .env.test
  context "iphone heic on R2", vcr: {cassette_name: "process_public_image_job-heic_r2", preserve_exact_body_bytes: true} do
    let(:image_path) { "spec/fixtures/bike_photo-gps.heic" }
    let(:public_image) { FactoryBot.create(:public_image, imageable: bike, file: r2_blob) }
    let(:dimensions) { [2400, 1800] }
    # Fixed key - the cassette matches on path, so a generated one would never replay
    let(:r2_blob) do
      ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join(image_path)),
        filename: "bike_photo-gps.heic", key: "spec-process-public-image-heic", service_name: :cloudflare_test)
    end

    it "converts to webp and strips exif from the original and from every variant" do
      source_fields = exif_fields(File.binread(Rails.root.join(image_path)))
      expect(source_fields.grep(identifying).count).to eq 25 # 15 of them GPS, down to the bearing
      expect(blob.service_name).to eq "cloudflare_test"
      expect(blob.content_type).to eq "image/heic"

      instance.perform(public_image.id)

      expect(blob.reload.binx_data).to eq target_binx_data
      expect(blob.content_type).to eq "image/webp"
      expect(blob.filename.to_s).to eq "bike_photo-gps.webp"
      original_data = blob.download
      expect(Vips::Image.new_from_buffer(original_data, "").get("vips-loader")).to start_with "webpload"
      expect(exif_fields(original_data)).to be_empty

      # vips copies exif through a transform, so a variant is only clean because the original
      # was rewritten first - and it re-synthesizes orientation/resolution/colorspace
      PublicImage::VARIANTS.each_key do |size|
        variant_fields = exif_fields(public_image.file.variant(size).download)
        expect(variant_fields.grep(identifying)).to be_empty
        expect(variant_fields).to include("exif-ifd0-Orientation")
      end
    end
  end

  context "imageable that isn't a bike" do
    let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: FactoryBot.create(:organization)) }

    it "stamps no bike" do
      instance.perform(public_image.id)

      expect(blob.reload.binx_data).to eq target_binx_data.except("bike_id")
    end
  end

  describe "enqueueing" do
    it "enqueues for an attached file, not for carrierwave" do
      expect {
        FactoryBot.create(:public_image, :with_attached_file, imageable: bike)
      }.to change(described_class.jobs, :size).by(1)
      # ActiveStorage owns metadata now, so its AnalyzeJob runs as normal
      expect(Sidekiq::ActiveJob::Wrapper.jobs.map { it["wrapped"] }).to eq ["ActiveStorage::AnalyzeJob"]

      expect {
        FactoryBot.create(:public_image, :with_image_file, imageable: bike)
      }.to_not change(described_class.jobs, :size)
    end

    # A second run would strip the original twice and race the first's writes to the blob
    it "doesn't enqueue again for a save while the first run is still working" do
      expect {
        public_image # The attachment, and the only enqueue it gets
      }.to change(described_class.jobs, :size).by(1)

      expect {
        public_image.update(listing_order: 2, kind: "photo_of_serial", is_private: true, name: "Renamed")
      }.to_not change(described_class.jobs, :size)

      expect(public_image.reload.file_needs_processing?).to be_truthy
    end
  end
end
