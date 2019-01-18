FactoryBot.define do
  factory :b_param do
    transient do
      owner_email { "bike_owner@example.com" }
    end
    creator { FactoryBot.create(:user) }
    params { { bike: { owner_email: owner_email } } }

    factory :b_param_stolen do
      params { { bike: { owner_email: owner_email, stolen: true } } }
    end

    factory :organized do
      # This factory should not be used directly, it's here to wrap organization
      transient do
        organization { FactoryBot.create(:organization) }
      end
      factory :b_param_partial_registration do
        transient do
          manufacturer { FactoryBot.create(:manufacturer) }
        end
        origin { "embed_partial" }
        params do
          {
            bike: {
              revised_new: true,
              manufacturer_id: manufacturer.id,
              owner_email: owner_email,
              creation_organization_id: organization.id
            }
          }
        end
      end
      factory :b_param_with_creation_organization do
        params do
          {
            bike: {
              owner_email: owner_email,
              creation_organization_id: organization.id
            }
          }
        end
      end
      factory :b_param_stolen_with_creation_organization do
        params do
          {
            bike: {
              owner_email: owner_email,
              creation_organization_id: organization.id,
              stolen: true
            }
          }
        end
      end
    end
  end
end
