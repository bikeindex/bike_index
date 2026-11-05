# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RegistrationsController#toggle_legacy_view", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { nil }

  it "opts the session into the legacy view, then back out" do
    post toggle_legacy_view_registration_path(bike, show_legacy: true)
    expect(response).to redirect_to(bike_path(bike))
    expect(session[:registration_show_legacy]).to be_truthy

    post toggle_legacy_view_registration_path(bike, show_legacy: false)
    expect(response).to redirect_to(registration_path(bike))
    expect(session[:registration_show_legacy]).to be_falsey
  end

  it "sets the state the button names, however many times it's submitted" do
    2.times do
      post toggle_legacy_view_registration_path(bike, show_legacy: true)
      expect(response).to redirect_to(bike_path(bike))
      expect(session[:registration_show_legacy]).to be_truthy
    end

    2.times do
      post toggle_legacy_view_registration_path(bike, show_legacy: false)
      expect(response).to redirect_to(registration_path(bike))
      expect(session[:registration_show_legacy]).to be_falsey
    end
  end

  it "carries the page's query through, as a string rather than url options" do
    post toggle_legacy_view_registration_path(bike, show_legacy: true, t: "token", scanned_id: "XD8888")
    expect(response).to redirect_to(bike_path(bike, t: "token", scanned_id: "XD8888"))

    post "/registrations/#{bike.id}/toggle_legacy_view?show_legacy=false&script_name=//example.com"
    expect(response.location).to eq "http://www.example.com/registrations/#{bike.id}?script_name=%2F%2Fexample.com"
  end

  context "signing in after opting out" do
    let(:password) { "example_password2" }
    let!(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }

    it "carries the session opt-out onto the account" do
      post toggle_legacy_view_registration_path(bike, show_legacy: true)
      post "/session", params: {session: {email: user.email, password:}}

      expect(user.reload.feature_registration_show_legacy).to be_truthy
      expect(session[:registration_show_legacy]).to be_blank
    end

    it "leaves the account alone when they never opted out" do
      post "/session", params: {session: {email: user.email, password:}}

      expect(user.reload.feature_registration_show_legacy).to be_falsey
    end

    context "user unconfirmed" do
      let!(:user) { FactoryBot.create(:user, password:, password_confirmation: password) }

      it "keeps the opt-out in the session until they confirm" do
        RearGearType.fixed
        post toggle_legacy_view_registration_path(bike, show_legacy: true)
        post "/session", params: {session: {email: user.email, password:}}
        expect(user.reload.feature_registration_show_legacy).to be_falsey
        get bike_path(bike)
        expect(response).to render_template(:show)

        user.confirm(user.confirmation_token)
        post "/session", params: {session: {email: user.email, password:}}
        expect(user.reload.feature_registration_show_legacy).to be_truthy
        expect(session[:registration_show_legacy]).to be_blank
      end
    end

    context "user invalid for an unrelated reason" do
      before { user.update_column(:preferred_language, "xx") }

      it "keeps the opt-out in the session, until a signed-in toggle clears it" do
        RearGearType.fixed
        post toggle_legacy_view_registration_path(bike, show_legacy: true)
        post "/session", params: {session: {email: user.email, password:}}
        expect(user.reload.feature_registration_show_legacy).to be_falsey
        expect(session[:registration_show_legacy]).to be_truthy
        get bike_path(bike)
        expect(response).to render_template(:show)

        user.update_column(:preferred_language, "en")
        post toggle_legacy_view_registration_path(bike, show_legacy: false)
        expect(response).to redirect_to(registration_path(bike))
        get bike_path(bike)
        expect(response).to redirect_to(registration_path(bike))
      end
    end
  end

  context "redesign disabled" do
    before { Flipper.enable(:registration_redesign_disabled) }

    it "records the preference and redirects to the classic page either way" do
      post toggle_legacy_view_registration_path(bike, show_legacy: true)
      expect(response).to redirect_to(bike_path(bike))
      expect(session[:registration_show_legacy]).to be_truthy

      post toggle_legacy_view_registration_path(bike, show_legacy: false)
      expect(response).to redirect_to(bike_path(bike))
      expect(session[:registration_show_legacy]).to be_falsey
    end
  end

  context "user logged in" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "opts into the legacy view, and follows the account when another device opts back in" do
      post toggle_legacy_view_registration_path(bike, show_legacy: true)
      expect(response).to redirect_to(bike_path(bike))
      expect(current_user.reload.feature_registration_show_legacy).to be_truthy

      current_user.update(feature_registration_show_legacy: false)
      get bike_path(bike)
      expect(response).to redirect_to(registration_path(bike))
    end

    context "user opted into the legacy view" do
      let(:current_user) { FactoryBot.create(:user_confirmed, feature_registration_show_legacy: true) }

      it "opts back out and redirects to the redesign" do
        post toggle_legacy_view_registration_path(bike, show_legacy: false)
        expect(response).to redirect_to(registration_path(bike))
        expect(current_user.reload.feature_registration_show_legacy).to be_falsey
      end
    end

    context "user invalid for an unrelated reason" do
      before { current_user.update_column(:preferred_language, "xx") }

      it "flashes an error and returns to the view they came from" do
        post toggle_legacy_view_registration_path(bike, show_legacy: true)
        expect(response).to redirect_to(registration_path(bike))
        expect(flash[:error]).to match(/unable to update/i)
        expect(current_user.reload.feature_registration_show_legacy).to be_falsey
      end
    end
  end
end
