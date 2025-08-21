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
FactoryBot.define do
  factory :mailchimp_value do
    list { MailchimpValue.lists.first }
    kind { MailchimpValue.kinds.first }
    sequence(:mailchimp_id) { |n| "oqweqwe#{n}" }
    data { {} }
  end
end
