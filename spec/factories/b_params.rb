FactoryBot.define do
  factory :b_param do
    transient do
      owner_email { "bike_owner@bikeindex.org" }
    end
    creator { FactoryBot.create(:user) }
    params { {bike: {owner_email: owner_email}} }

    factory :b_param_stolen do
      params { {bike: {owner_email: owner_email, date_stolen: Time.current.to_i}} }
    end

    # What BParam#unfinished_registration? requires: step 1 submitted (manufacturer_id),
    # registered to an address of the creator's rather than for someone else. A real
    # manufacturer, since set_manufacturer_key turns an id that resolves to nothing into
    # the Other manufacturer named after it
    factory :b_param_unfinished_registration do
      transient do
        manufacturer { Manufacturer.find_by(name: "Surly") || FactoryBot.create(:manufacturer, name: "Surly") }
      end
      origin { "register_flow" }
      owner_email { creator.email }
      params { {bike: {manufacturer_id: manufacturer.id, cycle_type: "cargo", owner_email: owner_email}} }
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
