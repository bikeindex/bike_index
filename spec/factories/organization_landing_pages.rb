FactoryBot.define do
  factory :organization_landing_page do
    organization
    body { "<p>Welcome to the landing page</p>" }
  end
end
