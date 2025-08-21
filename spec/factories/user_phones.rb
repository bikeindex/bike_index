# == Schema Information
#
# Table name: user_phones
#
#  id                :bigint           not null, primary key
#  confirmation_code :string
#  confirmed_at      :datetime
#  deleted_at        :datetime
#  phone             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :bigint
#
# Indexes
#
#  index_user_phones_on_user_id  (user_id)
#
FactoryBot.define do
  factory :user_phone do
    user { FactoryBot.create(:user) }
    sequence(:phone) { |n| n.to_s.rjust(7, "2") }
    factory :user_phone_confirmed do
      confirmed_at { Time.current - 1.minutes }
    end
  end
end
