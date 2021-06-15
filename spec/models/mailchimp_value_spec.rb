require "rails_helper"

RSpec.describe MailchimpValue, type: :model do
  it "has the same lists as integration" do
    expect(MailchimpValue.lists).to match_array(MailchimpIntegration::LISTS.keys.map(&:to_s))
  end
end
