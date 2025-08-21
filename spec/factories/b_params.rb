# == Schema Information
#
# Table name: b_params
#
#  id              :integer          not null, primary key
#  bike_errors     :text
#  bike_title      :string(255)
#  email           :string
#  id_token        :text
#  image           :string(255)
#  image_processed :boolean          default(FALSE)
#  image_tmp       :string(255)
#  origin          :string
#  params          :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_bike_id :integer
#  creator_id      :integer
#  organization_id :integer
#
# Indexes
#
#  index_b_params_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :b_param do
    transient do
      owner_email { "bike_owner@example.com" }
    end
    creator { FactoryBot.create(:user) }
    params { {bike: {owner_email: owner_email}} }

    factory :b_param_stolen do
      params { {bike: {owner_email: owner_email, date_stolen: Time.current.to_i}} }
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
