require "rails_helper"

RSpec.describe CarrierWaveProcessJob, type: :job do
  before { PublicImageUploader.enable_processing = true }
  after { PublicImageUploader.enable_processing = false }

  # The job only runs in production, where fog storage lets versions defer to it.
  # Simulate that so uploads defer (test storage is local file, where they wouldn't).
  before { allow_any_instance_of(PublicImage).to receive(:remote_storage?).and_return(true) }

  def image_metadata(path)
    `identify -verbose #{path} 2>/dev/null`
  end

  # PublicImage's default_scope hides is_private records; without an unscoped
  # lookup the worker raised NoMethodError on a nil record, so a private image's
  # deferred versions were never generated.
  it "generates the deferred versions for a private image" do
    image_file = File.open(Rails.root.join("spec", "fixtures", "bike.jpg"))
    public_image = FactoryBot.create(:public_image, imageable: FactoryBot.create(:bike), image: image_file, is_private: true)
    image_file.close
    expect(public_image.reload.is_private).to be_truthy
    expect(File.exist?(public_image.image.small.path)).to be_falsey

    described_class.new.perform("PublicImage", public_image.id.to_s, "image")

    expect(File.exist?(public_image.reload.image.small.path)).to be_truthy
    public_image.image.remove!
  end

  # PublicImageUploader defers with Backgrounder::Delay, so fix_exif_rotation and
  # strip are skipped on the synchronous upload; the worker reruns them on the
  # original (and the versions it derives) rather than leaving EXIF/metadata behind.
  it "orients and strips the original and its versions" do
    image_file = File.open(Rails.root.join("spec", "fixtures", "exif_orientation.jpg"))
    public_image = FactoryBot.create(:public_image, imageable: FactoryBot.create(:bike), image: image_file)
    image_file.close
    # The synchronously-stored original is still raw
    expect(image_metadata(public_image.image.path)).to include("SECRET-EXIF-METADATA")

    described_class.new.perform("PublicImage", public_image.id.to_s, "image")

    public_image.reload
    original_metadata = image_metadata(public_image.image.path)
    expect(original_metadata).to_not include("SECRET-EXIF-METADATA")
    expect(original_metadata).to_not match(/Orientation:\s*LeftBottom/)
    expect(image_metadata(public_image.image.small.path)).to_not include("SECRET-EXIF-METADATA")
    public_image.image.remove!
  end
end
