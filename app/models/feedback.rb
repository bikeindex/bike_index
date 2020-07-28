class Feedback < ApplicationRecord
  validates_presence_of :body, :email, :title
  belongs_to :user
  before_validation :set_calculated_attributes
  attr_accessor :additional

  after_create :notify_admins

  scope :notification_types, -> { where.not(feedback_type: no_notification_types) }
  scope :no_notification_types, -> { where(feedback_type: no_notification_types) }

  def self.no_notification_types
    %w[manufacturer_update_request serial_update_request bike_delete_request]
  end

  def self.bike(bike_or_bike_id = nil)
    return where("(feedback_hash->>'bike_id') IS NOT NULL") if bike_or_bike_id.blank?
    bike_id = bike_or_bike_id.is_a?(Bike) ? bike_or_bike_id.id : bike_or_bike_id
    where("(feedback_hash->>'bike_id') = ?", bike_id.to_s)
  end

  def self.feedback_types
    # Quick semi-hack to get a list of types, good enough till it's not ;)
    @feedback_types ||= distinct.pluck(:feedback_type).reject(&:blank?)
  end

  def package_size=(val)
    self.feedback_hash = (feedback_hash || {}).merge(package_size: val)
  end

  def phone_number=(val)
    self.feedback_hash = (feedback_hash || {}).merge(phone_number: val)
  end

  def notify_admins
    if delete_request? && bike.present?
      if bike.current_impound_record.present?
        impound_update = bike.current_impound_record.impound_record_updates.new(user_id: user_id, kind: "removed_from_bike_index")
        impound_update.save
      else
        bike.destroy
      end
    end
    return true if self.class.no_notification_types.include?(feedback_type)
    EmailFeedbackNotificationWorker.perform_async(id)
  end

  def delete_request?
    feedback_type == "bike_delete_request"
  end

  def bike_id
    (feedback_hash || {})["bike_id"]
  end

  def bike
    Bike.unscoped.where(id: bike_id).first
  end

  def package_size
    (feedback_hash || {})["package_size"]
  end

  def phone_number
    (feedback_hash || {})["phone_number"]
  end

  def humanized_type
    return "msg" unless feedback_type.present?
    lead_type || feedback_type.gsub("_request", "").humanize
  end

  def set_calculated_attributes
    generate_title
    set_user_attrs
    self.body ||= "lead" if lead?
  end

  def looks_like_spam?
    return false if user.present?
    # We're permitting unsigned in users to send messages for leads, if they try to send additional
    additional.present?
  end

  def generate_title
    return true if title.present? || lead_type.blank?
    self.title = "New #{lead_type} lead: #{name}"
  end

  def set_user_attrs
    return true unless user.present?
    self.name ||= user.name
    self.email ||= user.email
  end

  def lead?
    feedback_type && feedback_type =~ /lead_for_/
  end

  def lead_type
    return nil unless lead?
    feedback_type.gsub(/lead_for_/, "").humanize
  end
end
