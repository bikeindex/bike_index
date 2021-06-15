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
  validates :user_id, uniqueness: true, allow_blank: true
  validate :ensure_subscription_required, on: :create

  before_validation :set_calculated_attributes
  after_commit :update_association_and_mailchimp, if: :persisted?

  enum status: STATUS_ENUM

  attr_accessor :creator_feedback

  scope :user_deleted, -> { where.not(user_deleted_at: nil) }
  scope :on_mailchimp, -> { where.not(mailchimp_updated_at: nil) }

  # obj can be a user, a feedback or an email
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

  def on_mailchimp?
    mailchimp_updated_at.present?
  end

  # Lists aka "Audiences"
  def lists
    data&.dig("lists") || []
  end

  def tags
    data&.dig("tags") || []
  end

  # Interests aka "Groups"
  def interests
    data&.dig("interests") || []
  end

  # Mailchimp interests by id
  def mailchimp_interests
    data&.dig("mailchimp_interests") || {}
  end

  # TODO: make this lookup the IDs for mailchimp_value interests and add them
  def add_mailchimp_interests(list, val)
    new_values = val.select { |k, v| v.present? }.keys
    self.data ||= {}
    self.data["mailchimp_interests"] = mailchimp_interests.dup.merge(list => new_values)
  end

  def mailchimp_merge_fields
    data&.dig("mailchimp_merge_fields") || {}
  end

  def mailchimp_merge_fields=(val)
    new_values = val.select { |k, v| v.present? }.to_h
    self.data["mailchimp_merge_fields"] = mailchimp_merge_fields.dup.merge(new_values)
  end

  def full_name
    user&.name
  end

  def subscriber_hash
    Digest::MD5.hexdigest(email)
  end

  def mailchimp_status
    no_subscription_required? ? "unsubscribed" : status
  end

  def set_calculated_attributes
    self.user ||= User.fuzzy_email_find(email) if email.present?
    if user.present?
      self.email = user.email
      self.user_deleted_at = nil
    elsif user_id.present?
      self.user_deleted_at ||= Time.current
    end
    self.email = EmailNormalizer.normalize(email)
    self.data ||= {}
    @previous_data = data # I don't trust dirty with json
    self.data = data.merge(calculated_data)
    @previous_status = status # For some reason this doesn't work with dirty either
    self.status = calculated_status
  end

  def update_association_and_mailchimp
    calculated_feedbacks.each do |f|
      next if f.mailchimp_datum_id.present?
      f.update(mailchimp_datum_id: id)
    end
    return true if data == @previous_data && status == @previous_status
    UpdateMailchimpDatumWorker.perform_async(id)
  end

  def ensure_subscription_required
    return true if !no_subscription_required? || on_mailchimp?
    errors.add(:base, "No mailchimp subscription required, so not creating")
  end

  def member_hash(list = nil)
    MailchimpIntegration.member_hash(self, list)
  end

  def calculated_data
    {
      lists: calculated_lists,
      tags: calculated_tags,
      interests: calculated_interests,
      mailchimp_interests: mailchimp_interests,
      mailchimp_merge_fields: mailchimp_merge_fields,
    }
  end

  def merge_fields
    {
      organization_name: mailchimp_organization&.name,
      organization_signed_up_at: mailchimp_organization&.created_at,
      organization_country: mailchimp_organization&.country&.iso,
      organization_city: mailchimp_organization&.city,
      organization_state: mailchimp_organization&.state&.abbreviation,
      bikes: 0,
      name: full_name,
      phone_number: user&.phone,
      user_signed_up_at: user&.created_at,
      added_to_mailchimp_at: nil,
      most_recent_donation_at: nil,
      number_of_donations: 0
    }
  end

  private

  def calculated_tags
    updated_tags = tags.dup
    updated_tags << "in-index" if user.present?
    if mailchimp_organization.present?
      unless mailchimp_organization_membership.organization_creator?
        updated_tags << "not-organization-creator"
      end
      if %w[lightspeed_pos ascend_pos].include?(mailchimp_organization.pos_kind)
        updated_tags << mailchimp_organization.pos_kind.gsub("_pos", "")
        updated_tags << "pos-approved"
      end
      if mailchimp_organization.paid?
        updated_tags << "paid"
      elsif mailchimp_organization.paid_previously?
        updated_tags << "paid-previously"
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
    c_list = lists.dup
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
