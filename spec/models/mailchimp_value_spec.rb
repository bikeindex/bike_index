# == Schema Information
#
# Table name: mailchimp_values
#
#  id           :bigint           not null, primary key
#  data         :jsonb
#  kind         :integer
#  list         :integer
#  name         :string
#  slug         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  mailchimp_id :string
#
require "rails_helper"

RSpec.describe MailchimpValue, type: :model do
  it "has the same lists as integration" do
    expect(MailchimpValue.lists).to match_array(Integrations::Mailchimp::LISTS.keys.map(&:to_s))
  end
end
