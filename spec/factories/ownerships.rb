# Recently added the :with_ownership trait to bikes
# Most places where this factory is used should instead use that instead
# == Schema Information
#
# Table name: ownerships
#
#  id                            :integer          not null, primary key
#  claimed                       :boolean          default(FALSE)
#  claimed_at                    :datetime
#  current                       :boolean          default(FALSE)
#  example                       :boolean          default(FALSE), not null
#  is_new                        :boolean          default(FALSE)
#  is_phone                      :boolean          default(FALSE)
#  organization_pre_registration :boolean          default(FALSE)
#  origin                        :integer
#  owner_email                   :string(255)
#  owner_name                    :string
#  pos_kind                      :integer
#  registration_info             :jsonb
#  skip_email                    :boolean          default(FALSE)
#  status                        :integer
#  token                         :text
#  user_hidden                   :boolean          default(FALSE), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  bike_id                       :integer
#  bulk_import_id                :bigint
#  creator_id                    :integer
#  impound_record_id             :bigint
#  organization_id               :bigint
#  previous_ownership_id         :bigint
#  user_id                       :integer
#
# Indexes
#
#  index_ownerships_on_bike_id            (bike_id)
#  index_ownerships_on_bulk_import_id     (bulk_import_id)
#  index_ownerships_on_creator_id         (creator_id)
#  index_ownerships_on_impound_record_id  (impound_record_id)
#  index_ownerships_on_organization_id    (organization_id)
#  index_ownerships_on_user_id            (user_id)
#
FactoryBot.define do
  factory :ownership do
    creator { FactoryBot.create(:user_confirmed) }
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    bike { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    current { true }
    created_at { bike&.created_at } # This makes testing certain time related things easier
    trait :claimed do
      claimed { true }
      user { creator } # Reduce the number of things added to the database
      owner_email { user.email }
      claimed_at { Time.current - 1.hour }
    end
    factory :ownership_claimed, traits: [:claimed]
  end
end
