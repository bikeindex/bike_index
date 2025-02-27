# == Schema Information
#
# Table name: theft_alerts
#
#  id                          :integer          not null, primary key
#  ad_radius_miles             :integer
#  admin                       :boolean          default(FALSE)
#  amount_cents_facebook_spent :integer
#  end_at                      :datetime
#  facebook_data               :jsonb
#  facebook_updated_at         :datetime
#  latitude                    :float
#  longitude                   :float
#  notes                       :text
#  reach                       :integer
#  start_at                    :datetime
#  status                      :integer          default("pending"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  bike_id                     :bigint
#  payment_id                  :integer
#  stolen_record_id            :integer
#  theft_alert_plan_id         :integer
#  user_id                     :integer
#
# Indexes
#
#  index_theft_alerts_on_bike_id              (bike_id)
#  index_theft_alerts_on_payment_id           (payment_id)
#  index_theft_alerts_on_stolen_record_id     (stolen_record_id)
#  index_theft_alerts_on_theft_alert_plan_id  (theft_alert_plan_id)
#  index_theft_alerts_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (stolen_record_id => stolen_records.id) ON DELETE => cascade
#  fk_rails_...  (theft_alert_plan_id => theft_alert_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
class TheftAlert < ApplicationRecord
  # NOTE: TheftAlert is called "Promoted alert" on the frontend

  FAILED_DELAY = 5.minutes.to_i.freeze
  STATUS_ENUM = {pending: 0, active: 1, inactive: 2}.freeze
  # Timestamp 1s before first alert was automated
  AUTOMATION_START = 1625586988 # 2021-7-6

  enum :status, STATUS_ENUM

  validates :theft_alert_plan,
    :status,
    :user_id,
    presence: true

  validate :alert_cannot_begin_in_past_or_after_ends

  belongs_to :stolen_record
  belongs_to :theft_alert_plan
  belongs_to :payment
  belongs_to :user

  has_many :notifications, as: :notifiable

  before_validation :set_calculated_attributes

  scope :should_expire, -> { active.where('"theft_alerts"."end_at" <= ?', Time.current) }
  scope :paid, -> { joins(:payment).merge(Payment.paid) }
  scope :admin, -> { where(admin: true) }
  scope :not_admin, -> { where(admin: false) }
  scope :unpaid, -> { not_admin.joins(:payment).merge(Payment.incomplete) }
  scope :paid_or_admin, -> { paid.or(admin) }
  scope :posted, -> { where.not(start_at: nil) }
  scope :activating, -> { pending.where(start_at: nil).where("(facebook_data -> 'activating_at') IS NOT NULL") }
  scope :failed_to_activate, -> { activating.where("(facebook_data -> 'activating_at')::integer < ?", Time.current.to_i - FAILED_DELAY) }
  scope :creation_ordered_desc, -> { order(created_at: :desc) }
  scope :facebook_updateable, -> { where("(facebook_data -> 'campaign_id') IS NOT NULL") }
  scope :should_update_facebook, -> { facebook_updateable.where("theft_alerts.end_at > ?", update_end_buffer) }

  delegate :duration_days, :duration_days_facebook, :amount_cents, to: :theft_alert_plan
  delegate :country, :city, :state, :zipcode, :street, to: :stolen_record, allow_nil: true

  geocoded_by nil

  class << self
    def statuses
      STATUS_ENUM.keys.map(&:to_s)
    end

    def update_end_buffer
      Time.current - 2.days
    end

    def flatten_city(counted)
      @countries ||= Country.pluck(:id, :name).to_h
      @states ||= State.pluck(:id, :name).to_h

      [@countries[counted[0][0]], counted[0][1], @states[counted[0][2]], counted[1]]
    end

    def cities_count
      joins(:stolen_record)
        .group("stolen_records.country_id", "stolen_records.city", "stolen_records.state_id")
        .count
        .map { |c| flatten_city(c) }
        .sort_by { |c| -c[3] }
    end

    def paid_cents
      paid.sum("payments.amount_cents")
    end

    def facebook_integration
      "Facebook::AdsIntegration".constantize
    rescue
      nil
    end

    def matching_adset_objective(objective)
      where("(facebook_data ->> 'objective_adset') = ?", objective)
        .or(where("(facebook_data ->> 'objective_campaign') = ?", objective))
    end
  end

  # Override because of recovered bikes not being in default scope
  def stolen_record
    return nil unless stolen_record_id.present?
    StolenRecord.current_and_not.find_by_id(stolen_record_id)
  end

  def bike
    stolen_record&.bike
  end

  # never geocode, use calculated lat/long
  def should_be_geocoded?
    false
  end

  def before_automation?
    (created_at || Time.current).to_i < AUTOMATION_START
  end

  def notify?
    return false if admin? || facebook_data.blank? || facebook_data&.dig("no_notify").present?
    stolen_record.present? && stolen_record.receive_notifications?
  end

  def paid?
    payment&.paid? || false
  end

  def live?
    posted? && facebook_data&.dig("effective_object_story_id").present? &&
      end_at > Time.current
  end

  # Active or has been active
  def posted?
    start_at.present?
  end

  def facebook_updateable?
    campaign_id.present?
  end

  def should_update_facebook?
    return false unless facebook_updateable?
    return false if end_at < self.class.update_end_buffer
    facebook_updated_at.blank? || facebook_updated_at < Time.current - 3.hours
  end

  # literally CAN NOT activate
  def activateable_except_approval?
    return false if missing_photo? || missing_location?
    admin ? true : paid?
  end

  # Probably don't want to activate
  def activateable?
    activateable_except_approval? && stolen_record_approved?
  end

  def activating?
    pending? && activating_at.present?
  end

  # Simplistic, can be improved
  def failed_to_activate?
    activating? && failed_to_activate_data?
  end

  # Some alerts have been manually overridden to be inactive - make it possible to show this state
  def failed_to_activate_inactive?
    inactive? && failed_to_activate_data? && start_at.blank?
  end

  def recovered?
    stolen_record&.recovered?
  end

  def missing_location?
    latitude.blank? && longitude.blank?
  end

  def paid_at
    payment&.paid_at
  end

  def address_string
    stolen_record&.address(force_show_address: true, country: [:iso])
  end

  def stolen_record_approved?
    stolen_record&.approved? || false
  end

  def missing_photo?
    !stolen_record&.current_alert_image.present?
  end

  def facebook_name(kind = "campaign")
    n = "Theft Alert #{id} - #{amount_facebook}"
    return n if kind == "campaign"
    "#{n} - #{kind}"
  end

  def amount_cents_facebook
    return facebook_data["amount_cents"] if facebook_data&.dig("amount_cents").present?
    theft_alert_plan&.amount_cents_facebook
  end

  def amount_facebook
    MoneyFormatter.money_format(amount_cents_facebook)
  end

  def amount_facebook_spent
    MoneyFormatter.money_format(amount_cents_facebook_spent)
  end

  def activating_at
    t = facebook_data&.dig("activating_at")
    t.present? ? TimeParser.parse(t) : nil
  end

  def facebook_post_url
    return nil unless facebook_data&.dig("effective_object_story_id").present?
    "https://facebook.com/#{facebook_data&.dig("effective_object_story_id")}"
  end

  def campaign_id
    facebook_data&.dig("campaign_id")
  end

  def adset_id
    facebook_data&.dig("adset_id")
  end

  def ad_id
    facebook_data&.dig("ad_id")
  end

  def engagement
    facebook_data&.dig("engagement") || {}
  end

  def objective_campaign
    return nil if campaign_id.blank?
    facebook_data&.dig("objective_campaign")
  end

  def objective_adset
    return nil if campaign_id.blank?
    facebook_data&.dig("objective_adset")
  end

  def message
    "#{stolen_record&.city}: Keep an eye out for this stolen #{bike.mnfg_name}. If you see it, let the owner know on Bike Index!"
  end

  def start_at_with_fallback
    start_at.present? ? start_at : Time.current
  end

  # Default to 3 days, because something
  def calculated_end_at
    start_at_with_fallback + (duration_days_facebook || 3).days
  end

  def set_calculated_attributes
    if stolen_record&.latitude.present?
      self.latitude = stolen_record.latitude
      self.longitude = stolen_record.longitude
    end
    self.bike_id = stolen_record&.bike_id
    self.ad_radius_miles = theft_alert_plan&.ad_radius_miles unless admin
    self.amount_cents_facebook_spent = calculated_cents_facebook_spent
  end

  private

  def failed_to_activate_data?
    activating_at < Time.current - FAILED_DELAY
  end

  def alert_cannot_begin_in_past_or_after_ends
    return if start_at.blank? && end_at.blank?

    if start_at.blank?
      errors.add(:start_at, :must_be_present)
    elsif end_at.blank?
      errors.add(:end_at, :must_be_present)
    elsif start_at >= end_at
      errors.add(:end_at, :must_be_later_than_start_time)
    end
  end

  def calculated_cents_facebook_spent
    facebook_data&.dig("spend_cents")
  end
end
