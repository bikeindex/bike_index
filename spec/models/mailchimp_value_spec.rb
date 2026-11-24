require "rails_helper"

RSpec.describe MailchimpValue, type: :model do
  it "has the same lists as integration" do
    expect(MailchimpValue.lists).to match_array(Integrations::Mailchimp::LISTS.keys.map(&:to_s))
  end

  describe "slugify" do
    it "matches organization kinds" do
      expect(MailchimpValue.slugify("School / University")).to eq "school"
      expect(MailchimpValue.slugify("Law Enforcement / Municipality")).to eq "law_enforcement"
      expect(MailchimpValue.slugify("Other kind of organization")).to eq "other"
      expect(MailchimpValue.slugify("Bike Shop")).to eq "bike_shop"
    end
  end
end
