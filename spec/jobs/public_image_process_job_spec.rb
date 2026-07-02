require "rails_helper"

RSpec.describe PublicImageProcessJob, type: :job do
  before { PublicImageUploader.enable_processing = true }
  after { PublicImageUploader.enable_processing = false }

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
end
