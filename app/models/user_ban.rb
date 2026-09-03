# == Schema Information
#
# Table name: user_bans
# Database name: primary
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  reason      :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :bigint
#  user_id     :bigint
#
# Indexes
#
#  index_user_bans_on_user_id  (user_id)
#
class UserBan < ApplicationRecord
  REASON_ENUM = {
    abuse: 0,
    extortion: 1,
    known_criminal: 2,
    bad_actor: 3,
    spamming: 4,
    seo_spam: 5
  }.freeze

  # Overrides for reasons that don't read well when humanized
  REASON_DISPLAY = {"seo_spam" => "SEO SPAM"}.freeze

  acts_as_paranoid

  enum :reason, REASON_ENUM

  belongs_to :user
  belongs_to :creator, class_name: "User"

  validates_presence_of :reason, :user_id

  after_commit :update_user_on_create, on: :create

  def self.reasons
    REASON_ENUM.keys.map(&:to_s)
  end

  def self.reason_humanized(reason)
    return if reason.blank?

    REASON_DISPLAY[reason.to_s] || reason.to_s.humanize
  end

  def reason_humanized
    self.class.reason_humanized(reason)
  end

  def update_user_on_create
    return if id.blank?

    # Ban the user and sign them out (one save, via update_auth_token)
    user.banned = true
    user.update_auth_token("auth_token")
    # Remove (not delete) their marketplace listings, then flag bikes as likely spam
    # (listings first — the listing's bike-sync callback needs a still-visible bike)
    user.marketplace_listings.current.each { it.update(status: "removed") }
    user.bikes(true).each { it.update(likely_spam: true) }
  end
end
