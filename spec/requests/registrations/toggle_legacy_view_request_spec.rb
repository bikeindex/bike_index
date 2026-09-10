# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RegistrationsController#toggle_legacy_view", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { nil }

  it "opts the session into the legacy view, then back out" do
    post toggle_legacy_view_registration_path(bike)
    expect(response).to redirect_to(bike_path(bike))
    expect(session[:registration_show_legacy]).to be_truthy

    post toggle_legacy_view_registration_path(bike)
    expect(response).to redirect_to(registration_path(bike))
    expect(session[:registration_show_legacy]).to be_falsey
  end

  context "signing in after opting out" do
    let(:password) { "example_password2" }
    let!(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }

    it "carries the session opt-out onto the account" do
      post toggle_legacy_view_registration_path(bike)
      post "/session", params: {session: {email: user.email, password:}}

      expect(user.reload.feature_registration_show_legacy).to be_truthy
      expect(session[:registration_show_legacy]).to be_blank
    end

    it "leaves the account alone when they never opted out" do
      post "/session", params: {session: {email: user.email, password:}}

      expect(user.reload.feature_registration_show_legacy).to be_falsey
    end
  end

  context "user logged in" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "opts into the legacy view and redirects to the legacy page" do
      post toggle_legacy_view_registration_path(bike)
      expect(response).to redirect_to(bike_path(bike))
      expect(current_user.reload.feature_registration_show_legacy).to be_truthy
    end

    context "user opted into the legacy view" do
      let(:current_user) { FactoryBot.create(:user_confirmed, feature_registration_show_legacy: true) }

      it "opts back out and redirects to the redesign" do
        post toggle_legacy_view_registration_path(bike)
        expect(response).to redirect_to(registration_path(bike))
        expect(current_user.reload.feature_registration_show_legacy).to be_falsey
      end
    end

    context "user invalid for an unrelated reason" do
      before { current_user.update_column(:preferred_language, "xx") }

      it "flashes an error and returns to the view they came from" do
        post toggle_legacy_view_registration_path(bike)
        expect(response).to redirect_to(registration_path(bike))
        expect(flash[:error]).to match(/unable to update/i)
        expect(current_user.reload.feature_registration_show_legacy).to be_falsey
      end
    end
  end
end
