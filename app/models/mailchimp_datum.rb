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
      mailchimp_datum ||= where(email: obj.email).first
      mailchimp_datum || create(email: obj.email, user: obj.user, creator_feedback: obj)
    else
      fail "Unable to create mailchimp data for #{obj}"
    end
  end

  def user_deleted?
    user_deleted_at.present?
  end

  # Lists aka "Audiences"
  def lists
    @lists ||= data["lists"] || []
  end

  def tags
    data["tags"] || []
  end

  # interests aka "Groups"
  def interests_individual
    data["interests_individual"] || []
  end

  def interests_organization
    data["interests_organization"] || []
  end

  def set_calculated_attributes
    if user.present?
      self.email = user.email
      self.user_deleted_at = nil
    elsif user_id.present?
      self.user_deleted_at ||= Time.current
    end
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
    # pp @previous_data, data, @previous_data == data
    return true if @previous_data == data
    UpdateMailchimpDatumWorker.perform_async(id)
  end

  def ensure_subscription_required
    return true unless no_subscription_required?
    errors.add(:base, "No mailchimp subscription required, so not creating")
  end

  def calculated_data
    new_lists = calculated_lists
    {
      lists: new_lists,
      tags: calculated_tags,
      interests_organization: calculated_interests_organization(new_lists),
      interests_individual: calculated_interests_individual(new_lists),
    }
  end

  private

  def calculated_tags
    updated_tags = tags
    updated_tags
  end

  def calculated_status
    return "unsubscribed" if user_deleted?
    return status if status.present? &&
      !%w[subscribed no_subscription_required].include?(status)
    return "no_subscription_required" if lists.none?
    "subscribed"
  end

  def calculated_feedbacks
    c_feedbacks = user.present? ? user.feedbacks : Feedback.where(email: email)
    (c_feedbacks + [creator_feedback]).compact
  end

  def calculated_lists
    c_list = []
    if calculated_feedbacks.any? { |f| f.lead? }
      c_list << "organization"
    elsif user&.has_membership? # No need to calculate this if there is a lead
      c_list << "organization" if user.memberships.any? { |u| u.admin? }
    end
    c_list
  end

  def calculated_interests_individual(new_lists)
    updated_interests_i = interests_individual
    return updated_interests_i unless new_lists.include?("individual")
    updated_interests_i
  end

  def calculated_interests_organization(new_lists)
    updated_interests_o = interests_individual
    return updated_interests_o unless new_lists.include?("organization")
    updated_interests_o
  end
end
