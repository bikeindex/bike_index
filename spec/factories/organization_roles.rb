# == Schema Information
#
# Table name: organization_roles
#
#  id                       :integer          not null, primary key
#  claimed_at               :datetime
#  created_by_magic_link    :boolean          default(FALSE)
#  deleted_at               :datetime
#  email_invitation_sent_at :datetime
#  hot_sheet_notification   :integer          default("notification_never")
#  invited_email            :string(255)
#  receive_hot_sheet        :boolean          default(FALSE)
#  role                     :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  organization_id          :integer          not null
#  sender_id                :integer
#  user_id                  :integer
#
# Indexes
#
#  index_organization_roles_on_organization_id  (organization_id)
#  index_organization_roles_on_sender_id        (sender_id)
#  index_organization_roles_on_user_id          (user_id)
#
FactoryBot.define do
  factory :organization_role do
    role { "member" }
    organization { FactoryBot.create(:organization) }
    sender { FactoryBot.create(:user_confirmed) }
    sequence(:invited_email) { |n| user&.email || "someone-#{n}@test.com" }

    factory :organization_role_claimed do
      user { FactoryBot.create(:user_confirmed) }
      email_invitation_sent_at { Time.current }
      claimed_at { Time.current }

      factory :organization_role_ambassador do
        organization { FactoryBot.create(:organization_ambassador) }
      end
    end
  end
end
