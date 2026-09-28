FactoryBot.define do
  factory :organization_signup do
    email { "org_admin@bikeindex.org" }

    # Step 1 saved
    factory :organization_signup_started do
      name { "Shifty Bike Shop" }
      kind { "bike_shop" }

      # Step 2 saved - everything but the email confirmation
      factory :organization_signup_details_completed do
        website { "shiftybikes.com" }
        phone { "7183839999" }
        address { {street: "10544 82 Ave NW", city: "Edmonton", postal_code: "T6E 2A4", country_id: Country.canada_id}.as_json }
        details_completed_at { Time.current }
      end
    end
  end
end
