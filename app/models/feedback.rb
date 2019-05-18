class Feedback < ActiveRecord::Base
  validates_presence_of :body, :email, :title
  serialize :feedback_hash
  belongs_to :user
  before_validation :set_calculated_attributes
  attr_accessor :additional, :package_size

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

  def package_size=(val)
    self.feedback_hash = (feedback_hash || {}).merge(package_size: val)
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

  def lead?; feedback_type && feedback_type =~ /lead_for_/ end

  def lead_type
    return nil unless lead?
    feedback_type.gsub(/lead_for_/, "").humanize
  end
end
