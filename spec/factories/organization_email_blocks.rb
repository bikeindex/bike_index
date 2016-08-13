FactoryGirl.define do
  factory :organization_email_block do
    block_type OrganizationEmailBlock.block_types.first
    association :organization
    body 'some text'
  end
end
