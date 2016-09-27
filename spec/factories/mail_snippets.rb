FactoryGirl.define do
  factory :mail_snippet do
    name
    is_enabled true
    body '<p>Foo</p>'
    factory :location_triggered_mail_snippet do
      is_location_triggered true
      proximity_radius 100
      address 'New York, NY'
    end
    factory :organization_mail_snippet do
      sequence(:name) { |n| MailSnippet.organization_snippet_types[MailSnippet.organization_snippet_types.count%n] }
      association :organization
    end
  end
end
