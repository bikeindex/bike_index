# == Schema Information
#
# Table name: feedbacks
#
#  id                 :integer          not null, primary key
#  body               :text
#  email              :string(255)
#  feedback_hash      :jsonb
#  feedback_type      :string(255)
#  kind               :integer
#  name               :string(255)
#  title              :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  mailchimp_datum_id :bigint
#  user_id            :integer
#
class Feedback < ApplicationRecord
  KIND_ENUM = {
    message: 0,
    bike_delete_request: 1,
    serial_update_request: 2,
    manufacturer_update_request: 3,
    bike_recovery: 4,
    tip_stolen_bike: 5,
    tip_chop_shop: 6,
    organization_created: 7,
    organization_destroyed: 8,
    lead_for_bike_shop: 9,
    lead_for_city: 10,
    lead_for_school: 11,
    lead_for_law_enforcement: 12
  }.freeze

  validates_presence_of :body, :email, :title

  belongs_to :user
  belongs_to :mailchimp_datum

  before_validation :set_calculated_attributes

  enum :kind, KIND_ENUM

  attr_accessor :additional

  after_create :notify_admins

  scope :notification, -> { where.not(feedback_type: no_notification_kinds) }
  scope :no_notification, -> { where(feedback_type: no_notification_kinds) }
  scope :stolen_tip, -> { where(kind: stolen_tip_kinds) }
  scope :no_user, -> { where(user_id: nil) }
  scope :lead, -> { where(kind: lead_types) }
  scope :mailchimping, -> { where(kind: mailchimping_kinds) }

  def self.no_notification_kinds
    %w[manufacturer_update_request serial_update_request bike_delete_request]
  end

  def self.lead_types
    %w[lead_for_bike_shop lead_for_city lead_for_school lead_for_law_enforcement]
  end

  # May be additional kinds in the future
  def self.mailchimping_kinds
    lead_types
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

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.stolen_tip_kinds
    %w[tip_stolen_bike tip_chop_shop]
  end

  def self.kind_humanized(str)
    return nil unless str.present?
    return "#{str.gsub("lead_for_", "").strip.humanize} lead" if str.match?("lead")
    str.gsub("_request", "").strip.humanize
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
    return true if self.class.no_notification_kinds.include?(kind)
    EmailFeedbackNotificationWorker.perform_async(id)
  end

  def delete_request?
    bike_delete_request? # Holdover from feedback_type > kind enum conversion
  end

  def mailchimping?
    self.class.mailchimping_kinds.include?(kind)
  end

  def bike_id
    (feedback_hash || {})["bike_id"]
  end

  def bike
    Bike.unscoped.where(id: bike_id).first
  end

  def organization_id
    feedback_hash&.dig("organization_id")
  end

  def organization
    organization_id.present? && Organization.find_by_id(organization_id)
  end

  def package_size
    (feedback_hash || {})["package_size"]
  end

  def phone_number
    (feedback_hash || {})["phone_number"]
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  # Legacy method - TODO: replace with kind_humanized
  def humanized_type
    kind_humanized
  end

  def set_calculated_attributes
    generate_title
    set_user_attrs
    self.email = EmailNormalizer.normalize(email)
    self.kind ||= calculated_kind
    self.body ||= "lead" if lead?
    self.feedback_type ||= kind
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
    feedback_type&.match?(/lead_for_/) || kind&.match?(/lead_for_/)
  end

  def lead_type
    return nil unless lead?
    kind_str = feedback_type if feedback_type.present?
    kind_str ||= kind
    kind_str.gsub("lead_for_", "").humanize
  end

  private

  # Temporary fix - migrating to enum from a string
  # Some types have been removed - they no longer are relevant: organization_map, spokecard, shop_submission
  def calculated_kind
    return feedback_type if self.class.kinds.include?(feedback_type)
    if feedback_type == "stolen_information"
      return title&.match?(/chop.?shop/i) ? "tip_chop_shop" : "tip_stolen_bike"
    end
    "message"
  end
end
