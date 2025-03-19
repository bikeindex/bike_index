# == Schema Information
#
# Table name: email_bans
#
#  id            :bigint           not null, primary key
#  end_at        :datetime
#  reason        :integer
#  start_at      :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_email_id :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_email_bans_on_user_email_id  (user_email_id)
#  index_email_bans_on_user_id        (user_id)
#
class EmailBan < ApplicationRecord
  include ActivePeriodable

  REASON_ENUM = {email_domain: 0, email_duplicate: 1, delivery_failure: 2}

  belongs_to :user
  belongs_to :email_ban

  enum :reason, REASON_ENUM

  validates_presence_of :reason
  validate :is_not_duplicate_ban

  before_validation :set_calculated_attributes

  def set_calculated_attributes
    self.start_at ||= Time.current
  end

  def is_not_duplicate_ban
    matching_previous_ban = self.class.where(user_id:, reason:).period_active_at(start_at)
      .where.not(id:)
    matching_previous_ban = matching_previous_ban.where("id < ?", id) if id.present?
    return if matching_previous_ban.none?

    errors.add(:user_id, "there is already an active email_ban for the same reason for that user")
  end
end
