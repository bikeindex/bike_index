require "rails_helper"

RSpec.describe PosRegistrationMatchesController, type: :request do
  let(:pos_registration_match) { FactoryBot.create(:pos_registration_match, :different_email) }
  let(:url) { "/pos_registration_matches/#{pos_registration_match.token}" }

  it "shows both registrations without signing in, obscuring the owner's email" do
    get url
    expect(response.status).to eq 200
    owner_email = pos_registration_match.bike.user.email
    expect(response.body).to include("Is this the same bike?", EmailNormalizer.obfuscate(owner_email),
      "name=\"answer\"", "action=\"#{url}\"")
    expect(response.body).not_to include(owner_email)
  end

  it "combines them" do
    patch url, params: {answer: "merge"}
    expect(response).to redirect_to(root_path)
    expect(flash[:success]).to include("We're combining them")
    expect(pos_registration_match.reload).to have_attributes(status: "confirmed", merger_id: nil)

    BikeJobs::MergePosRegistrationJob.drain
    expect(pos_registration_match.reload.status).to eq "merged"
    get url
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to include("already combined")
  end

  it "keeps them separate" do
    patch url, params: {answer: "decline"}
    expect(flash[:success]).to eq "Thanks, we'll keep them as separate registrations."
    expect(pos_registration_match.reload.status).to eq "declined"
    expect(BikeJobs::MergePosRegistrationJob.jobs).to be_empty
  end

  it "404s without the token" do
    get "/pos_registration_matches/wrong-token"
    expect(response.status).to eq 404
    patch "/pos_registration_matches/#{pos_registration_match.id}", params: {answer: "merge"}
    expect(response.status).to eq 404
    expect(pos_registration_match.reload.status).to eq "pending"
  end

  context "the owner's own match" do
    let(:pos_registration_match) { FactoryBot.create(:pos_registration_match) }

    it "404s, since it has no token" do
      expect(pos_registration_match.token).to be_nil
      get "/pos_registration_matches/"
      expect(response.status).to eq 404
    end
  end
end
