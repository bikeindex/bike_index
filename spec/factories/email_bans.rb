# == Schema Information
#
# Table name: email_bans
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  reason     :integer
#  start_at   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_email_bans_on_user_id  (user_id)
#
FactoryBot.define do
  factory :email_ban do
    user { FactoryBot.create(:user_confirmed) }
    start_at { Time.current - 1.day }
    end_at { nil }
    reason { :email_domain }
  end
end
