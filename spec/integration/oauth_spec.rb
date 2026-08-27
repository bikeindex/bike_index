# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OAuth authorization", :js, type: :system do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:password) { "testthisthing7$" }
  # oob renders the code on a page instead of redirecting off-site, so the browser can read it
  let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app, redirect_uri: "urn:ietf:wg:oauth:2.0:oob") }
  let(:code_verifier) { "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" }
  let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false) }
  let(:authorize_path) do
    "/oauth/authorize?response_type=code&client_id=#{doorkeeper_app.uid}" \
      "&redirect_uri=#{CGI.escape(doorkeeper_app.redirect_uri)}&scope=read_bikes" \
      "&code_challenge=#{code_challenge}&code_challenge_method=S256"
  end

  # Redeeming is the client's own server call, not something the rider does. No
  # client_secret - a public client is the case PKCE exists for
  def redeem(code, code_verifier: nil)
    params = {grant_type: "authorization_code", code:, client_id: doorkeeper_app.uid,
              redirect_uri: doorkeeper_app.redirect_uri}
    params[:code_verifier] = code_verifier if code_verifier
    Net::HTTP.post_form(URI.join(Capybara.current_session.server.base_url, "/oauth/token"), params)
  end

  it "carries the challenge through the prompt, so only the verifier redeems the code" do
    visit authorize_path
    expect(page).to have_current_path("/session/new", wait: 5)

    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: password
    click_button "Log in"

    expect(page).to have_content("Would you like to authorize", wait: 5)
    click_button "Authorize"

    code = find("#authorization_code").text
    expect(Doorkeeper::AccessGrant.find_by(token: code).code_challenge).to eq code_challenge

    without_verifier = redeem(code)
    expect(without_verifier.code).to eq "400"
    expect(JSON.parse(without_verifier.body)["error"]).to eq "invalid_request"

    wrong_verifier = redeem(code, code_verifier: code_verifier.reverse)
    expect(wrong_verifier.code).to eq "400"
    expect(JSON.parse(wrong_verifier.body)["error"]).to eq "invalid_grant"
    expect(Doorkeeper::AccessToken.count).to eq 0

    redeemed = redeem(code, code_verifier:)
    expect(redeemed.code).to eq "200"
    expect(Doorkeeper::AccessToken.count).to eq 1
    expect(JSON.parse(redeemed.body)["access_token"]).to eq Doorkeeper::AccessToken.last.token
  end
end
