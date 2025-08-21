# == Schema Information
#
# Table name: superuser_abilities
#
#  id              :bigint           not null, primary key
#  action_name     :string
#  controller_name :string
#  deleted_at      :datetime
#  kind            :integer          default("universal")
#  su_options      :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint
#
# Indexes
#
#  index_superuser_abilities_on_user_id  (user_id)
#
FactoryBot.define do
  factory :superuser_ability do
    user { FactoryBot.create(:user_confirmed) }
  end
end
