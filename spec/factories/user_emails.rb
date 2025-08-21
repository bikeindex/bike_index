# == Schema Information
#
# Table name: user_emails
#
#  id                 :integer          not null, primary key
#  confirmation_token :text
#  email              :string(255)
#  last_email_errored :boolean          default(FALSE)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  old_user_id        :integer
#  user_id            :integer
#
# Indexes
#
#  index_user_emails_on_user_id  (user_id)
#
FactoryBot.define do
  factory :user_email do
    user { FactoryBot.create(:user_confirmed) }
    email { generate(:unique_email) }
  end
end
