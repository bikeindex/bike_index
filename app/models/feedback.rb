class Feedback < ActiveRecord::Base
  validates_presence_of :body, :email, :title
  serialize :feedback_hash
  belongs_to :user
  before_validation :generate_title, :set_user_attrs

  after_create :notify_admins
  def notify_admins
    return true if no_notification_types.include?(feedback_type)
    EmailFeedbackNotificationWorker.perform_async(id)
  end

  def no_notification_types
    %w(manufacturer_update_request serial_update_request)
  end

  def bike
    feedback_hash && feedback_hash[:bike_id] && Bike.unscoped.find(feedback_hash[:bike_id])
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

  def lead_type
    return nil unless feedback_type && feedback_type =~ /lead_for_/
    feedback_type.gsub(/lead_for_/, '').humanize
  end
end
