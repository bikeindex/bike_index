require "rails_helper"

RSpec.describe ImageJobs::AttachBlobJob, type: :job do
  let(:instance) { described_class.new }
  let(:bike) { FactoryBot.create(:bike) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
      filename: "bike.jpg", content_type: "image/jpeg")
  end
  let(:b_param) { FactoryBot.create(:b_param, params: {"image_signed_id" => blob.signed_id}) }
  before { blob.update!(binx_data: {"b_param_id" => b_param.id}) }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "attaches the blob to the bike" do
    instance.perform(b_param.id, bike.id)
    expect(bike.public_images.first.file.blob).to eq blob
  end

  context "R2 still unavailable" do
    before do
      blob.update!(identified: false)
      allow_any_instance_of(blob.service.class).to receive(:download_chunk)
        .and_raise(Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new))
    end

    it "raises, so sidekiq retries it" do
      expect { instance.perform(b_param.id, bike.id) }.to raise_error(Seahorse::Client::NetworkingError)
      expect(bike.public_images.count).to eq 0
    end
  end

  context "b_param gone" do
    it "does nothing" do
      instance.perform(b_param.id + 1, bike.id)
      expect(bike.public_images.count).to eq 0
    end
  end
end
