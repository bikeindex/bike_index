# frozen_string_literal: true

require "rails_helper"

RSpec.describe RegistrationView do
  let(:bike) { FactoryBot.create(:bike) }
  let(:user) { nil }
  let(:session_show_legacy) { nil }
  let(:registration_view) { described_class.new(user:, session_show_legacy:) }

  it "shows the redesign, carrying the query" do
    expect(registration_view.show_legacy?).to be_falsey
    expect(registration_view.path(bike, t: "token")).to eq "/registrations/#{bike.id}?t=token"
    expect(registration_view.path(bike, show_legacy: true)).to eq "/bikes/#{bike.id}"
  end

  context "session opted into the legacy view" do
    let(:session_show_legacy) { true }

    it "shows the legacy page" do
      expect(registration_view.show_legacy?).to be_truthy
      expect(registration_view.path(bike)).to eq "/bikes/#{bike.id}"
    end
  end

  context "user opted into the legacy view" do
    let(:user) { FactoryBot.create(:user_confirmed, feature_registration_show_legacy: true) }

    it "shows the legacy page" do
      expect(registration_view.show_legacy?).to be_truthy
      expect(registration_view.path(bike)).to eq "/bikes/#{bike.id}"
    end
  end

  context "redesign disabled" do
    before { Flipper.enable(:registration_redesign_disabled) }

    it "shows the legacy page even to a viewer who hasn't opted out" do
      expect(registration_view.redesign_enabled?).to be_falsey
      expect(registration_view.path(bike, show_legacy: false)).to eq "/bikes/#{bike.id}"
    end
  end
end
