require "rails_helper"

RSpec.describe UpdateMailchimpValuesJob, type: :job do
  let(:instance) { described_class.new }

  it "enqueues all" do
    Sidekiq::Job.clear_all
    expect(UpdateMailchimpValuesJob.jobs.count).to eq 0
    instance.perform
    expect(UpdateMailchimpValuesJob.jobs.count).to eq 8
  end

  let(:target_interest_categories_data) { {list_id: "b675299293", id: "2e650f9110", title: "Organization type", display_order: 0, type: "checkboxes"} }
  context "interest_category" do
    it "gets and creates the values" do
      expect(MailchimpValue.interest_category.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-interest_category", match_requests_on: [:path]) do
        instance.perform("organization", "interest_category")
      end
      expect(MailchimpValue.interest_category.count).to eq 1
      mailchimp_value = MailchimpValue.last
      expect(mailchimp_value.name).to eq "Organization type"
      expect(mailchimp_value.slug).to eq "organization_type"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "2e650f9110"
      expect(mailchimp_value.data.as_json).to eq target_interest_categories_data.as_json

      # Doesn't create more
      VCR.use_cassette("update_mailchimp_values_worker-interest_category", match_requests_on: [:path]) do
        instance.perform("organization", "interest_category")
      end
      expect(MailchimpValue.interest_category.count).to eq 1
    end
  end

  context "interests" do
    let!(:interest_category) { MailchimpValue.create(list: "organization", kind: "interest_category", data: target_interest_categories_data) }
    let(:target_data) { {category_id: "2e650f9110", list_id: "b675299293", id: "cbca7bf705", name: "Bike shop", subscriber_count: "1361", display_order: 1} }
    it "gets and creates the values" do
      expect(MailchimpValue.interest.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-interest", match_requests_on: [:path]) do
        instance.perform("organization", "interest")
      end
      expect(MailchimpValue.interest.count).to eq 3
      mailchimp_value = MailchimpValue.organization.friendly_find("cbca7bf705")
      expect(mailchimp_value.name).to eq "Bike shop"
      expect(mailchimp_value.slug).to eq "bike_shop"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "cbca7bf705"
      expect(mailchimp_value.data.as_json).to eq target_data.as_json

      # Doesn't create more
      VCR.use_cassette("update_mailchimp_values_worker-interest", match_requests_on: [:path]) do
        instance.perform("organization", "interest")
      end
      expect(MailchimpValue.interest.count).to eq 3
    end
  end

  context "tags" do
    let(:target_data) { {id: 87314, name: "Lightspeed"} }
    it "gets tags" do
      expect(MailchimpValue.tag.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-tag", match_requests_on: [:path]) do
        instance.perform("organization", "tag")
      end
      expect(MailchimpValue.tag.count).to eq 7
      mailchimp_value = MailchimpValue.organization.friendly_find("Lightspeed")
      expect(mailchimp_value.name).to eq "Lightspeed"
      expect(mailchimp_value.slug).to eq "lightspeed"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "87314"
      expect(mailchimp_value.data.as_json).to eq target_data.as_json

      # Doesn't create more
      VCR.use_cassette("update_mailchimp_values_worker-tag", match_requests_on: [:path]) do
        instance.perform("organization", "tag")
      end
      expect(MailchimpValue.tag.count).to eq 7
    end
  end

  context "merge_field" do
    let(:target_data) { {merge_id: 3, tag: "ADDRESS", name: "Address", type: "address", required: false, default_value: "", public: false, display_order: 4, options: {default_country: 164}, help_text: "", list_id: "b675299293"} }
    it "gets merge_field" do
      expect(MailchimpValue.merge_field.count).to eq 0
      VCR.use_cassette("update_mailchimp_values_worker-merge_field", match_requests_on: [:path]) do
        instance.perform("organization", "merge_field")
      end
      expect(MailchimpValue.merge_field.count).to eq 10
      mailchimp_value = MailchimpValue.organization.friendly_find("ADDress ")
      expect(mailchimp_value.name).to eq "Address"
      expect(mailchimp_value.slug).to eq "address"
      expect(mailchimp_value.list).to eq "organization"
      expect(mailchimp_value.mailchimp_id).to eq "ADDRESS"
      expect(mailchimp_value.data.as_json).to eq target_data.as_json

      # Doesn't create more
      VCR.use_cassette("update_mailchimp_values_worker-merge_field", match_requests_on: [:path]) do
        instance.perform("organization", "merge_field")
      end
      expect(MailchimpValue.merge_field.count).to eq 10
    end
  end
end
