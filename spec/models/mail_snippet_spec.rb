require "rails_helper"

RSpec.describe MailSnippet, type: :model do
  it_behaves_like "geocodeable"

  describe "disable_if_blank" do
    it "sets unenabled if body is blank" do
      mail_snippet = MailSnippet.new(is_enabled: true, body: nil, kind: "welcome")
      expect(mail_snippet.is_enabled).to be_truthy
      mail_snippet.save
      expect(mail_snippet.is_enabled).to be_falsey
      expect(mail_snippet.kind).to eq "welcome"
    end
  end

  describe "kinds" do
    it "includes all the ParkingNotification kinds" do
      expect((MailSnippet.kinds & ParkingNotification.kinds).count).to eq(ParkingNotification.kinds.count)
    end
  end
end
