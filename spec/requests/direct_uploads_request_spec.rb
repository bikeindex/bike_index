require "rails_helper"

# ActiveStorage's route resolves here rather than to its own controller, which checks nothing
RSpec.describe DirectUploadsController, type: :request do
  let(:base_url) { "/rails/active_storage/direct_uploads" }
  let(:blob) { {filename: "bike.jpg", content_type: "image/jpeg", byte_size: 1234, checksum: "x" * 22} }

  def post_upload(**overrides)
    post base_url, params: {blob: blob.merge(overrides)}
  end

  # The shadow depends on route order, so assert the dispatch - if ActiveStorage's own route
  # ever wins again, its controller accepts anything from anyone and nothing else would fail.
  # Driving the throttle to its limit isn't possible under the global requests/ip throttle
  # (12 in test), and the register endpoint's spec covers one actually returning 429 - so
  # this pins the configuration instead.
  it "shadows ActiveStorage's route and throttles it per IP by the minute" do
    expect(Rails.application.routes.url_helpers.rails_direct_uploads_path).to eq base_url
    expect(Rails.application.routes.recognize_path(base_url, method: :post))
      .to eq(controller: "direct_uploads", action: "create")

    throttle = Rack::Attack.throttles["direct_uploads/ip"]
    expect(throttle.limit).to eq Rack::Attack::DIRECT_UPLOAD_MAX
    expect(throttle.period).to eq 1.minute
  end

  context "signed out" do
    it "is forbidden" do
      post_upload
      expect(response.status).to eq 403
      expect(ActiveStorage::Blob.count).to eq 0
    end
  end

  context "signed in" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before { log_in(user) }

    it "issues a presigned upload, turning away what the uploader wouldn't accept" do
      post_upload
      expect(response.status).to eq 200
      expect(json_result["signed_id"]).to be_present
      expect(json_result.dig("direct_upload", "url")).to be_present

      post_upload(content_type: "application/pdf", filename: "invoice.pdf")
      expect(response.status).to eq 422

      post_upload(byte_size: PublicImageUploader::MAX_FILE_SIZE + 1)
      expect(response.status).to eq 422
      # Only the permitted one was minted
      expect(ActiveStorage::Blob.count).to eq 1
    end
  end
end
