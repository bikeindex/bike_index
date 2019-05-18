class Feedback < ActiveRecord::Base
  validates_presence_of :body, :email, :title
  serialize :feedback_hash
  belongs_to :user
  before_validation :generate_title, :set_user_attrs
  attr_accessor :additional # spam block attribute

  after_create :notify_admins

  scope :notification_types, -> { where.not(feedback_type: no_notification_types) }
  scope :no_notification_types, -> { where(feedback_type: no_notification_types) }

  def self.no_notification_types
    %w(manufacturer_update_request serial_update_request)
  end

  def notify_admins
    return true if self.class.no_notification_types.include?(feedback_type)
    EmailFeedbackNotificationWorker.perform_async(id)
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

  def lead?; feedback_type && feedback_type =~ /lead_for_/ end

  def lead_type
    return nil unless lead?
    feedback_type.gsub(/lead_for_/, "").humanize
  end
end
