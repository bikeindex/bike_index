require "rails_helper"

RSpec.describe Register::DirectUploadsController, type: :request do
  let(:base_url) { "/register/direct_uploads" }
  let(:b_param) { BParam.create(origin: "registration_flow") }
  let(:blob) { {filename: "bike.jpg", content_type: "image/jpeg", byte_size: 1234, checksum: "x" * 22} }

  def post_upload(token: b_param.id_token, **overrides)
    post base_url, params: {b_param_token: token, blob: blob.merge(overrides)}
  end

  it "issues a presigned upload for a registration's photo, ignoring the metadata posted with it" do
    post_upload
    expect(response.status).to eq 200
    expect(json_result["signed_id"]).to be_present
    expect(json_result.dig("direct_upload", "url")).to be_present
    # Stamped so only this registration can claim it
    expect(ActiveStorage::Blob.last.binx_data).to eq({"b_param_id" => b_param.id})

    # ActiveStorage permits the client's metadata; the stamps it might try to forge live in
    # binx_data, which it has no way to post to
    post_upload(metadata: {processed: true, b_param_id: b_param.id + 1})
    expect(response.status).to eq 200
    expect(ActiveStorage::Blob.last).to have_attributes(metadata: {},
      binx_data: {"b_param_id" => b_param.id})
  end

  it "is forbidden without a registration to scope the upload to" do
    post_upload(token: nil)
    expect(response.status).to eq 403

    post_upload(token: "not-a-token")
    expect(response.status).to eq 403
    expect(ActiveStorage::Blob.count).to eq 0
  end

  # The browser declares both, so this only turns away what doesn't even claim to be
  # permitted - PublicImage's validation is what checks the bytes, once there are some
  it "rejects a file the uploader wouldn't have accepted" do
    post_upload(content_type: "application/pdf", filename: "invoice.pdf")
    expect(response.status).to eq 422

    post_upload(byte_size: PublicImageUploader::MAX_FILE_SIZE + 1)
    expect(response.status).to eq 422

    post_upload(byte_size: 0)
    expect(response.status).to eq 422
    expect(ActiveStorage::Blob.count).to eq 0
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

  # Only an organization hands its registrations' tokens to somebody else
  context "somebody else's registration" do
    let(:b_param) { BParam.create(origin: "registration_flow", creator_id: FactoryBot.create(:user_confirmed).id) }

    it "is forbidden" do
      post_upload
      expect(response.status).to eq 403
      expect(ActiveStorage::Blob.count).to eq 0
    end
  end

  # The embed forms post here too. Their b_param is created by the organization's auto user,
  # so the person filling the form in holds nothing but the token - as with the form itself
  context "an organization's embed registration" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    # Created the same way the organizations controller creates one for the embed forms
    let(:b_param) do
      BParam.create(creator_id: organization.auto_user.id,
        params: {creation_organization_id: organization.id, embeded: true, bike: {}})
    end

    it "issues a presigned upload to whoever holds the token" do
      post_upload
      expect(response.status).to eq 200
      expect(ActiveStorage::Blob.last.binx_data).to eq({"b_param_id" => b_param.id})
    end
  end

  # Stays under the global requests/ip throttle (12 in test, see rails_helper) so it's this
  # throttle being measured and not that one
  describe "throttling" do
    include_context :rack_attack

    it "caps an IP at REGISTER_DIRECT_UPLOAD_MAX an hour" do
      Rack::Attack::REGISTER_DIRECT_UPLOAD_MAX.times { post_upload }
      expect(response.status).to eq 200

      post_upload
      expect(response.status).to eq 429
      expect(request.env["rack.attack.matched"]).to eq "register_direct_uploads/ip"
    end
  end
end
