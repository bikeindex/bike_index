class MailchimpDatum < ApplicationRecord
  STATUS_ENUM = {
    no_subscription_required: 0,
    subscribed: 1,
    unsubscribed: 2, # Should remove
    pending: 3, # Never should be in this status
    cleaned: 4
  }

  belongs_to :user
  has_many :feedbacks

  validates_presence_of :email
  validates_uniqueness_of :user_id
  validate :ensure_subscription_required, on: :create

  before_validation :set_calculated_attributes
  after_commit :update_association_and_mailchimp, if: :persisted?

  enum status: STATUS_ENUM

  attr_accessor :creator_feedback

  scope :user_deleted, -> { where.not(user_deleted_at: nil) }

  # obj can be a user or a feedback
  def self.find_or_create_for(obj)
    if obj.is_a?(User)
      where(user_id: obj.id).first || where(email: obj.confirmed_emails).first ||
        create(user: obj)
    elsif obj.is_a?(Feedback)
      mailchimp_datum = where(user_id: obj.user_id).first if obj.user_id.present?
      mailchimp_datum || where(email: obj.email).first ||
        create(email: obj.email, user: obj.user, creator_feedback: obj)
    else
      fail "Unable to create mailchimp data for #{obj}"
    end
  end

  def mailchimp_organization_membership
    # TODO: base this on the existing organization in the datum
    user&.memberships&.admin&.reorder(:created_at)&.last
  end

  def mailchimp_organization
    mailchimp_organization_membership&.organization
  end

  def user_deleted?
    user_deleted_at.present?
  end

  # Lists aka "Audiences"
  def lists
    @lists ||= data["lists"] || []
  end

  def tags
    data&.dig("tags") || []
  end

  # Interests aka "Groups"
  def interests
    data&.dig("interests") || []
  end

  def full_name
    user&.name
  end

  def mailchimp_status
    no_subscription_required? ? "unsubscribed" : status
  end

  def set_calculated_attributes
    if user.present?
      self.email = user.email
      self.user_deleted_at = nil
    elsif user_id.present?
      self.user_deleted_at ||= Time.current
    end
    self.subscriber_hash = Digest::MD5.hexdigest(email)
    self.data ||= {}
    @previous_data = data
    self.data = calculated_data
    self.status = calculated_status
  end

  def update_association_and_mailchimp
    calculated_feedbacks.each do |f|
      next if f.mailchimp_datum_id.present?
      f.update(mailchimp_datum_id: id)
    end
    return true if @previous_data == data
    UpdateMailchimpDatumWorker.perform_async(id)
  end

  def ensure_subscription_required
    return true unless no_subscription_required?
    errors.add(:base, "No mailchimp subscription required, so not creating")
  end

  def member_hash(list = nil)
    MailchimpIntegration.member_hash(self, list)
  end

  def calculated_data
    {
      lists: calculated_lists,
      tags: calculated_tags,
      interests: calculated_interests
    }
  end

  def merge_fields
    {
      organization_kind: "bike_shop",
      organization_name: mailchimp_organization&.name,
      organization_url: mailchimp_organization&.website,
      organization_country: mailchimp_organization&.country&.iso,
      organization_city: mailchimp_organization&.city,
      organization_state: mailchimp_organization&.state&.abbreviation,
      organization_signed_up_at: mailchimp_organization&.created_at,
      bikes: 0,
      name: full_name,
      phone_number: user&.phone,
      user_signed_up_at: user&.created_at,
      added_to_mailchimp_at: nil
    }
  end

  private

  def calculated_tags
    updated_tags = tags.dup
    updated_tags << "in_index" if user.present?
    if mailchimp_organization.present?
      unless mailchimp_organization_membership.organization_creator?
        updated_tags << "not_organization_creator"
      end
      if %w[lightspeed_pos ascend_pos].include?(mailchimp_organization.pos_kind)
        updated_tags << mailchimp_organization.pos_kind.gsub("_pos", "")
      end
    end
    updated_tags.uniq.sort
  end

  def calculated_status
    return "unsubscribed" if user_deleted?
    return status if status.present? &&
      !%w[subscribed no_subscription_required].include?(status)
    return "no_subscription_required" if lists.none?
    "subscribed"
  end

  def calculated_feedbacks
    user.present? ? user.feedbacks : Feedback.where(email: email) +
      [creator_feedback].compact
  end

  def calculated_lists
    c_list = []
    if calculated_feedbacks.any? { |f| f.lead? }
      c_list << "organization"
    elsif mailchimp_organization_membership.present?
      c_list << "organization"
    end
    c_list.uniq.sort
  end

  def calculated_interests
    updated_interests = interests.dup
    if mailchimp_organization.present?
      updated_interests << mailchimp_organization.kind
    else
      updated_interests += calculated_feedbacks.select { |f| f.lead? }
        .map { |f| f.kind.gsub(/lead_for_/, "") }
    end
    updated_interests.uniq.sort
  end
end
