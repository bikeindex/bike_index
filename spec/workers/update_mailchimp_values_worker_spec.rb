require "rails_helper"

RSpec.describe UpdateMailchimpValuesWorker, type: :job do
  let(:instance) { described_class.new }

  context "interest_category" do
    let(:target_data) { {display_order: 0} }
    it "gets and creates the values" do
      expect(MailchimpValue.interest_category.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-interest_category", match_requests_on: [:path]) do
        instance.perform("organization", "interest_category")
      end
      expect(MailchimpValue.interest_category.count).to eq 1
      mailchimp_value = MailchimpValue.last
      expect(mailchimp_value.slug).to eq "stuff"
      expect(mailchimp_value.display_name).to eq "stuff"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "bec514f886"
      expect(mailchimp_value.data).to eq target_data
    end
  end
end
