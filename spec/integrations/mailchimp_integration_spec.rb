require "rails_helper"

RSpec.describe MailchimpIntegration do
  let(:instance) { described_class.new }

  describe "get_lists" do
    let(:target) do
       [{name: "Individuals", id: "180a1141a4"},
       {name: "Organizations", id: "b675299293"}]
    end
    it "gets the lists" do
      VCR.use_cassette("mailchimp_integration-get_lists", match_requests_on: [:path]) do
        lists = instance.get_lists
        expect(lists.map { |l| l.slice("name", "id")}).to eq target.as_json
      end
    end
  end
end
