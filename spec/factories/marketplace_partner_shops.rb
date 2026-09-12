FactoryBot.define do
  factory :marketplace_partner_shop do
    transient do
      address_in { :new_york }
    end

    organization { FactoryBot.create(:organization, kind: "bike_shop") }
    location do
      FactoryBot.create(:location, :with_address_record, address_in:, organization:)
    end
    boxing_fee_cents { 7_500 }

    trait :active do
      status { "active" }
    end

    # active? isn't enough to take a drop-off - the organization needs the feature too
    trait :accepting do
      status { "active" }
      organization do
        FactoryBot.create(:organization_with_organization_features, kind: "bike_shop",
          enabled_feature_slugs: [MarketplacePartnerShop::FEATURE_SLUG])
      end
    end
  end
end
