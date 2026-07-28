require "rails_helper"

RSpec.describe DirectUploadsController, type: :request do
  let(:base_url) { "/rails/active_storage/direct_uploads" }
  let(:b_param) { BParam.create(origin: "registration_flow") }
  let(:blob) { {filename: "bike.jpg", content_type: "image/jpeg", byte_size: 1234, checksum: "x" * 22} }

  def post_upload(token: b_param.id_token, **overrides)
    post base_url, params: {b_param_token: token, blob: blob.merge(overrides)}
  end

  it "issues a presigned upload for a registration's photo" do
    post_upload
    expect(response.status).to eq 200
    expect(json_result["signed_id"]).to be_present
    expect(json_result.dig("direct_upload", "url")).to be_present
  end

  context "no registration token" do
    it "is forbidden" do
      post_upload(token: nil)
      expect(response.status).to eq 403
      expect(ActiveStorage::Blob.count).to eq 0
    end

    it "is forbidden for an unknown token" do
      post_upload(token: "not-a-token")
      expect(response.status).to eq 403
    end
  end

  context "signed in" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:b_param) { BParam.create(origin: "registration_flow", creator_id: user.id) }
    before { log_in(user) }

    it "issues a presigned upload for their own registration" do
      post_upload
      expect(response.status).to eq 200
    end
  end

  # The browser declares these and the presigned url is signed against them, so refusing
  # here is what makes an oversized or non-image upload impossible rather than just unused
  context "file the uploader wouldn't have accepted" do
    it "rejects a non-image content type" do
      post_upload(content_type: "application/pdf", filename: "invoice.pdf")
      expect(response.status).to eq 422
      expect(ActiveStorage::Blob.count).to eq 0
    end

    it "rejects one over the size cap" do
      post_upload(byte_size: PublicImageUploader::MAX_FILE_SIZE + 1)
      expect(response.status).to eq 422
      expect(ActiveStorage::Blob.count).to eq 0
    end

    it "rejects an empty one" do
      post_upload(byte_size: 0)
      expect(response.status).to eq 422
    end
  end

  # Every count here stays under the global requests/ip throttle (12 in test, see
  # rails_helper) so it's these throttles being measured and not that one
  describe "throttling" do
    include_context :rack_attack

    it "caps an anonymous IP at DIRECT_UPLOAD_IP_MAX an hour" do
      Rack::Attack::DIRECT_UPLOAD_IP_MAX.times { post_upload }
      expect(response.status).to eq 200

      post_upload
      expect(response.status).to eq 429
      expect(request.env["rack.attack.matched"]).to eq "direct_uploads/ip"
    end

    context "signed in" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:b_param) { BParam.create(origin: "registration_flow", creator_id: user.id) }
      before { log_in(user) }

      it "keys them to the user, past what their IP alone would allow" do
        (Rack::Attack::DIRECT_UPLOAD_IP_MAX + 1).times { post_upload }
        expect(response.status).to eq 200
        expect(Rack::Attack.direct_upload_user_id(Rack::Attack::Request.new(request.env)))
          .to eq user.id
      end
    end
  end
end
