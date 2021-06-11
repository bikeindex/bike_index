require "rails_helper"

RSpec.describe MailchimpIntegration do
  let(:instance) { described_class.new }

  describe "get_audiences" do
    let(:target) do
      [{name: "Police Departments", id: "0eb9428151"},
       {name: "Donors", id: "180a1141a4"},
       {name: "Universities", id: "564456d501"},
       {name: "Recovered bike owners", id: "692e788302"},
       {name: "Organizations", id: "b675299293"}]
    end
    it "gets the audiences" do
      VCR.use_cassette("mailchimp_integration-get_audiences", match_requests_on: [:path]) do
        audiences = instance.get_audiences
        expect(audiences.map { |l| l.slice("name", "id")}).to eq target.as_json
      end
    end
  end
end
