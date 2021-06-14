require "rails_helper"

RSpec.describe UpdateMailchimpValuesWorker, type: :job do
  let(:instance) { described_class.new }

  let(:target_interest_categories_data) { {list_id: "b675299293", id: "2e650f9110", title: "Organization type", display_order: 0, type: "checkboxes"} }
  context "interest_category" do
    it "gets and creates the values" do
      expect(MailchimpValue.interest_category.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-interest_category", match_requests_on: [:path]) do
        instance.perform("organization", "interest_category")
      end
      expect(MailchimpValue.interest_category.count).to eq 1
      mailchimp_value = MailchimpValue.last
      expect(mailchimp_value.display_name).to eq "Organization type"
      expect(mailchimp_value.slug).to eq "organization-type"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "2e650f9110"
      expect(mailchimp_value.data.as_json).to eq target_interest_categories_data.as_json
    end
  end

  context "interests" do
    let!(:interest_category) { MailchimpValue.create(list: "organization", kind: "interest_category", data: target_interest_categories_data)}
    let(:target_data) { {category_id: "2e650f9110", list_id: "b675299293", id: "cbca7bf705", name: "Bike shop", subscriber_count: "1361", display_order: 1} }
    it "gets and creates the values" do
      expect(MailchimpValue.interest.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-interest", match_requests_on: [:path]) do
        instance.perform("organization", "interest")
      end
      expect(MailchimpValue.interest.count).to eq 3
      mailchimp_value = MailchimpValue.organization.friendly_find("cbca7bf705")
      expect(mailchimp_value.display_name).to eq "Bike shop"
      expect(mailchimp_value.slug).to eq "bike-shop"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "cbca7bf705"
      expect(mailchimp_value.data.as_json).to eq target_data.as_json
    end
  end
end
