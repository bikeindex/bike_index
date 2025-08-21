FactoryBot.define do
  factory :mailchimp_value do
    list { MailchimpValue.lists.first }
    kind { MailchimpValue.kinds.first }
    sequence(:mailchimp_id) { |n| "oqweqwe#{n}" }
    data { {} }
  end
end
