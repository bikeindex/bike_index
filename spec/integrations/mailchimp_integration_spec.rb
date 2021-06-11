require "rails_helper"

RSpec.describe MailchimpIntegration do
  let(:instance) { described_class.new }

  describe "get_lists" do
    let(:target) do
      [{name: "Police Departments", id: "0eb9428151"},
       {name: "Donors", id: "180a1141a4"},
       {name: "Universities", id: "564456d501"},
       {name: "Recovered bike owners", id: "692e788302"},
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
