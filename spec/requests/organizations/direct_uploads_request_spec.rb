require "rails_helper"

RSpec.describe Organizations::DirectUploadsController, type: :request do
  let(:base_url) { "/embed/direct_uploads" }
  let(:organization) { FactoryBot.create(:organization_with_auto_user) }
  # Created the same way the organizations controller creates one for the embed forms
  let(:b_param) do
    BParam.create(creator_id: organization.auto_user.id,
      params: {creation_organization_id: organization.id, embeded: true, bike: {}})
  end
  let(:blob) { {filename: "bike.jpg", content_type: "image/jpeg", byte_size: 1234, checksum: "x" * 22} }

  def post_upload(token: b_param.id_token, **overrides)
    post base_url, params: {b_param_token: token, blob: blob.merge(overrides)}
  end

  # The organization's auto user created the registration, so whoever is filling in the form
  # holds nothing but the token - which is all the form itself is scoped by either
  it "issues a presigned upload for an embed registration's photo" do
    post_upload
    expect(response.status).to eq 200
    expect(json_result["signed_id"]).to be_present
    expect(json_result.dig("direct_upload", "url")).to be_present
    # Stamped so only this registration can claim it
    expect(ActiveStorage::Blob.last.binx_data).to eq({"b_param_id" => b_param.id})
  end

  it "is forbidden without an embed registration to scope the upload to" do
    post_upload(token: nil)
    expect(response.status).to eq 403

    post_upload(token: "not-a-token")
    expect(response.status).to eq 403
    expect(ActiveStorage::Blob.count).to eq 0
  end

  # Someone else's registration in the /register flow is reachable by its creator, not by
  # anyone holding the token - only an organization's is handed out that way
  context "a registration belonging to a user" do
    let(:b_param) { BParam.create(origin: "register_flow", creator_id: FactoryBot.create(:user_confirmed).id) }

    it "is forbidden" do
      post_upload
      expect(response.status).to eq 403
      expect(ActiveStorage::Blob.count).to eq 0
    end
  end

  it "rejects a file the uploader wouldn't have accepted" do
    post_upload(content_type: "application/pdf", filename: "invoice.pdf")
    expect(response.status).to eq 422

    post_upload(byte_size: PublicImageUploader::MAX_FILE_SIZE + 1)
    expect(response.status).to eq 422
    expect(ActiveStorage::Blob.count).to eq 0
  end

  # A shop registers bike after bike from the one address, so the hourly budget is too large
  # to drive under the global requests/ip throttle (12 in test) - pin it instead
  it "throttles per IP by the hour, more loosely than the registration flow's endpoint" do
    throttle = Rack::Attack.throttles["embed_direct_uploads/ip"]
    expect(throttle.limit).to eq Rack::Attack::EMBED_DIRECT_UPLOAD_MAX
    expect(throttle.period).to eq 1.hour
    expect(Rack::Attack::EMBED_DIRECT_UPLOAD_MAX).to be > Rack::Attack::REGISTER_DIRECT_UPLOAD_MAX
  end
end
