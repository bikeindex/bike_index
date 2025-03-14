# == Schema Information
#
# Table name: user_likely_spam_reasons
#
#  id         :bigint           not null, primary key
#  reason     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_user_likely_spam_reasons_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class UserLikelySpamReason < ApplicationRecord
  belongs_to :user
  REASON_ENUM = {email_domain: 0}

  enum :reason, REASON_ENUM

  validates_uniqueness_of :user_id, scope: [:reason]
end
