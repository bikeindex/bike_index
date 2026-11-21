# frozen_string_literal: true

require "rails_helper"

RSpec.describe LocalPath do
  describe "only" do
    it "keeps a path of our own" do
      expect(LocalPath.only("/bikes/12?contact_owner=true")).to eq "/bikes/12?contact_owner=true"
      expect(LocalPath.only("/oauth/authorize?client_id=xYz")).to eq "/oauth/authorize?client_id=xYz"
    end

    it "drops anything a browser would take off-site" do
      ["https://evil.example/steal", "//evil.example", "/\\evil.example", "/\t/evil.example",
        "/\n/evil.example", "evil.example", "", nil].each do |target|
        expect(LocalPath.only(target)).to be_nil, target.inspect
      end
    end
  end
end
