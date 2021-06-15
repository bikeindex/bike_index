require "rails_helper"

RSpec.describe UpdateMailchimpDatumWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    it "creates the given number of mailchimp_datums" do
      expect(MailchimpDatum.count).to eq 0
      VCR.use_cassette("fetch_mailchimp_members_worker-success", match_requests_on: [:path]) do
      end
    end
  end
end
