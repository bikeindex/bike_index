FactoryBot.define do
  factory :organization_landing_page do
    transient do
      landing_page_template { ERB.new(File.read(Rails.root.join("db/seeds/organization_landing_page.html.erb"))) }
    end
    organization
    # The seeded page, so the default body is the size and shape of a real one
    body { landing_page_template.result_with_hash(organization:) }
  end
end
