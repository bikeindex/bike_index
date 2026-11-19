# frozen_string_literal: true

require "rails_helper"

RSpec.describe RegistrationView do
  let(:bike) { FactoryBot.create(:bike) }
  let(:user) { nil }
  let(:session) { {} }

  it "shows the redesign, carrying the query" do
    expect(described_class.show_legacy?(user:, session:)).to be_falsey
    expect(described_class.path(bike, user:, session:, t: "token")).to eq "/registrations/#{bike.id}?t=token"
    expect(described_class.path(bike, user:, session:, show_legacy: true)).to eq "/bikes/#{bike.id}"
  end

  context "session opted into the legacy view" do
    let(:session) { {registration_show_legacy: true} }

    it "shows the legacy page" do
      expect(described_class.show_legacy?(user:, session:)).to be_truthy
      expect(described_class.path(bike, user:, session:)).to eq "/bikes/#{bike.id}"
    end
  end

  context "user opted into the legacy view" do
    let(:user) { FactoryBot.create(:user_confirmed, feature_registration_show_legacy: true) }

    it "shows the legacy page" do
      expect(described_class.show_legacy?(user:, session:)).to be_truthy
      expect(described_class.path(bike, user:, session:)).to eq "/bikes/#{bike.id}"
    end
  end
end
