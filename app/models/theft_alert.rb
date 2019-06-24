class TheftAlert < ActiveRecord::Base
  enum status: { pending: 0, active: 1, inactive: 2 }.freeze

  validates :stolen_record,
            :theft_alert_plan,
            :status,
            :creator,
            presence: true

  belongs_to :stolen_record
  belongs_to :theft_alert_plan
  belongs_to :payment
  belongs_to :creator,
             class_name: "User",
             foreign_key: :user_id

  scope :should_expire, -> { active.where('"theft_alerts"."end_at" <= ?', Time.current) }
  scope :creation_ordered_desc, -> { order(created_at: :desc) }

  delegate :bike, to: :stolen_record, allow_nil: true

  def begin!(facebook_post_url:, notes:)
    start_time = Time.current
    end_time = start_time + theft_alert_plan&.duration_days&.days

    attrs = {
      status: "active",
      facebook_post_url: facebook_post_url,
      begin_at: start_time,
      end_at: end_time.end_of_day,
      notes: notes,
    }
    update(attrs) if valid_state?(attrs)
  end

  def update_details!(facebook_post_url:, notes:)
    attrs = {
      status: self.status,
      facebook_post_url: facebook_post_url,
      notes: notes,
    }
    update(attrs) if valid_state?(attrs)
  end

  def end!
    attrs = {
      status: "inactive",
      facebook_post_url: facebook_post_url,
      begin_at: begin_at,
      end_at: end_at,
    }
    update(attrs) if valid_state?(attrs)
  end

  def reset!
    attrs = {
      status: "pending",
      facebook_post_url: "",
      begin_at: nil,
      end_at: nil,
    }
    update(attrs) if valid_state?(attrs)
  end

  private

  # Ensure fields have expected values for the target state's status
  def valid_state?(target_state)
    status = target_state.fetch(:status, self.status)
    begin_at = target_state.fetch(:begin_at, self.begin_at)
    end_at = target_state.fetch(:end_at, self.end_at)
    facebook_post_url = target_state.fetch(:facebook_post_url, self.facebook_post_url)

    case status
    when "pending"
      errors.add(:facebook_post_url, "must be blank when pending") if facebook_post_url.present?
      errors.add(:begin_at, "must be blank when pending") if begin_at.present?
      errors.add(:end_at, "must be blank when pending") if end_at.present?
    when "active", "inactive"
      errors.add(:facebook_post_url, "must be a valid url") if facebook_post_url.blank?
      errors.add(:begin_at, "must be present") if begin_at.blank?
      errors.add(:end_at, "must be present") if end_at.blank?
    end

    errors.none?
  end
end
