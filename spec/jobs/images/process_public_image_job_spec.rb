require "rails_helper"

RSpec.describe Images::ProcessPublicImageJob, type: :job do
  let(:instance) { described_class.new }
  let(:bike) { FactoryBot.create(:bike) }
  # Carries GPS EXIF and an orientation tag, which is the whole reason the job exists
  let(:public_image) { FactoryBot.create(:public_image, :with_attached_file, imageable: bike, image_path:) }
  let(:image_path) { "spec/fixtures/exif_orientation.jpg" }
  let(:blob) { public_image.reload.file.blob }

  def exif_fields(data)
    Vips::Image.new_from_buffer(data, "").get_fields.grep(/exif|gps/i)
  end

  it "strips exif, generates the variants and marks the blob" do
    expect(exif_fields(File.binread(Rails.root.join(image_path)))).to be_present
    expect(public_image.file_needs_processing?).to be_truthy
    original_key, original_checksum = blob.key, blob.checksum

    instance.perform(public_image.id)

    expect(blob.reload.metadata["stripped"]).to be_truthy
    stripped_data = blob.download
    expect(exif_fields(stripped_data)).to be_empty
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

  it "enqueues for an attached file, not for carrierwave" do
    expect {
      FactoryBot.create(:public_image, :with_attached_file, imageable: bike)
    }.to change(described_class.jobs, :size).by(1)

    expect {
      FactoryBot.create(:public_image, :with_image_file, imageable: bike)
    }.to_not change(described_class.jobs, :size)
  end
end
