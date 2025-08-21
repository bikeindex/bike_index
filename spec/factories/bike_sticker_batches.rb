# == Schema Information
#
# Table name: bike_sticker_batches
#
#  id                 :integer          not null, primary key
#  code_number_length :integer
#  notes              :text
#  prefix             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  organization_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_bike_sticker_batches_on_organization_id  (organization_id)
#  index_bike_sticker_batches_on_user_id          (user_id)
#
FactoryBot.define do
  factory :bike_sticker_batch do
    user { FactoryBot.create(:superuser) }
    sequence(:prefix) { |n| "G#{n}" }
  end
end
