class MailchimpDatum < ApplicationRecord
  STATUS_ENUM = {
    no_subscription_required: 0,
    subscribed: 1,
    unsubscribed: 2, # Should remove
    pending: 3, # Never should be in this status
    cleaned: 4
  }

  MANAGED_TAGS = %w[in-bike-index not-org-creator paid paid-previously pos-approved lightspeed ascend].freeze

  belongs_to :user
  has_many :feedbacks

  validates_presence_of :email
  validates :user_id, uniqueness: true, allow_blank: true
  validate :ensure_subscription_required, on: :create

  before_validation :set_calculated_attributes
  after_commit :update_association_and_mailchimp, if: :persisted?

  enum status: STATUS_ENUM

  attr_accessor :creator_feedback, :skip_update

  scope :no_user, -> { where(user_id: nil) }
  scope :with_user, -> { where.not(user_id: nil).where(user_deleted_at: nil) }
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

  def self.find_and_update_or_create_for(obj)
    mailchimp_datum = find_or_create_for(obj)
    return mailchimp_datum unless mailchimp_datum.should_update?
    mailchimp_datum.update(updated_at: Time.current)
    mailchimp_datum
  end

  def self.list(str)
    where("data->'lists' @> ?", [str].to_json)
  end

  # This finds the organization from the existing merge field, or uses the most recent organization
  def mailchimp_organization_membership
    return @mailchimp_organization_membership if defined?(@mailchimp_organization_membership)
    memberships = user&.memberships&.admin&.reorder(:created_at)
    return nil unless memberships.present? && memberships.any?
    existing_name = data&.dig("merge_fields", "organization-name")
    existing_org = Organization.friendly_find(existing_name) if existing_name.present?
    @mailchimp_organization_membership = memberships.where(organization_id: existing_org.id).last if existing_org.present?
    @mailchimp_organization_membership ||= memberships.last
  end

  def mailchimp_organization
    mailchimp_organization_membership&.organization
  end

  def stolen_records_recovered
    return StolenRecord.none if user.blank?
    StolenRecord.recovered.where(index_helped_recovery: true, bike_id: user.ownerships.pluck(:bike_id))
  end

  def should_update?
    return false if id.blank? ||
      mailchimp_updated_at.present? && mailchimp_updated_at > Time.current - 2.minutes
    true
  end

  def with_user?
    user.present?
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

  def merge_fields
    data&.dig("merge_fields") || {}
  end

  # I'm not gonna lie - these methods (mailchimp_...) kinda suck. Sorry
  def mailchimp_interests(list)
    interest_slugs = interests.dup.map { |t| MailchimpValue.interest.friendly_find(t, list: list)&.slug }.compact
    MailchimpValue.interest.where(list: list).order(:name).map do |mailchimp_value|
      [mailchimp_value.mailchimp_id, interest_slugs.include?(mailchimp_value.slug) ? true : false]
    end.compact.to_h
  end

  def add_mailchimp_interests(list, val)
    kept_interests = interests.dup.map do |i|
      MailchimpValue.interest.friendly_find(i, list: list)&.present? ? nil : i
    end.compact

    new_interests = val.map do |key, value|
      next unless ParamsNormalizer.boolean(value)
      MailchimpValue.interest.friendly_find(key, list: list)&.slug || key
    end.compact
    self.data ||= {}
    self.data["interests"] = (kept_interests + new_interests).compact.uniq.sort
  end

  def mailchimp_merge_fields(list)
    managed_merge_fields.dup.map do |k, v|
      next unless v.present?
      m_key = MailchimpValue.merge_field.friendly_find(k, list: list)&.mailchimp_id
      next unless m_key.present?
      [m_key, v]
    end.compact.to_h.merge(address_merge(list))
  end

  def add_mailchimp_merge_fields(list, val)
    kept_merge_fields = merge_fields.dup.map do |k, v|
      next if MailchimpValue.merge_field.friendly_find(k, list: list)&.present?
      [k, v]
    end.compact.to_h
    new_merge_fields = val.map do |key, value|
      next unless value.present?
      [MailchimpValue.merge_field.friendly_find(key, list: list)&.slug || key, value]
    end.compact.to_h
    self.data ||= {}
    self.data["merge_fields"] = kept_merge_fields.merge(new_merge_fields)
  end

  def mailchimp_tags(list)
    tag_slugs = tags.dup.map { |t| MailchimpValue.tag.friendly_find(t, list: list)&.slug }.compact
    MailchimpValue.tag.where(list: list).order(:name).map do |mailchimp_value|
      next unless MANAGED_TAGS.include?(mailchimp_value.slug)
      present = tag_slugs.include?(mailchimp_value.slug)
      {name: mailchimp_value.name, status: present ? "active" : "inactive"}
    end.compact
  end

  def add_mailchimp_tags(list, val)
    kept_tags = tags.dup.map do |t|
      MailchimpValue.tag.friendly_find(t, list: list)&.present? ? nil : t
    end.compact
    new_tags = val.map do |hash|
      MailchimpValue.tag.friendly_find(hash["name"], list: list)&.slug || hash["name"]
    end
    self.data ||= {}
    self.data["tags"] = (new_tags + kept_tags).uniq.sort
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
    self.user_id ||= User.fuzzy_email_find(email)&.id if email.present?
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
    return true if skip_update
    calculated_feedbacks.each do |f|
      next if f.mailchimp_datum_id.present?
      f.update(mailchimp_datum_id: id)
    end
    return true unless should_update?
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
      merge_fields: managed_merge_fields.reject { |_k, v| v.blank? }
    }.as_json
  end

  def managed_merge_fields
    {
      "organization-name" => mailchimp_organization&.short_name,
      "organization-signed-up-at" => mailchimp_date(mailchimp_organization&.created_at),
      "bikes" => user&.bikes&.count || 0,
      "name" => full_name,
      "phone-number" => user&.phone,
      "signed-up-at" => mailchimp_date(user&.created_at),
      "most-recent-donation-at" => most_recent_donation_at,
      "number-of-donations" => user&.payments&.donation&.count || 0,
      "recovered-bike-at" => most_recent_recovery_at
    }
  end

  def address_merge(list)
    if list == "organization"
      return {} unless mailchimp_organization&.default_location.present? && mailchimp_organization&.city.present?
      {"O_CITY" => mailchimp_organization.city,
       "O_STATE" => mailchimp_organization.state&.abbreviation,
       "O_COUNTRY" => mailchimp_organization.country&.iso}
    else
      {} # For now, not handling
    end
  end

  private

  def mailchimp_date(datetime = nil)
    datetime&.to_date&.to_s
  end

  def most_recent_donation_at
    return nil unless user.present?
    mailchimp_date(user.payments.donation.maximum(:created_at))
  end

  def most_recent_recovery_at
    mailchimp_date(stolen_records_recovered.maximum(:recovered_at))
  end

  # NOTE: If adding more tags, make sure to add the tags to MANAGED_TAGS
  # or else it won't update mailchimp
  def calculated_tags
    updated_tags = tags.dup
    updated_tags << "in-bike-index" if user.present?
    if mailchimp_organization.present?
      unless mailchimp_organization_membership.organization_creator?
        updated_tags << "not-org-creator"
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
    (user.present? ? user.feedbacks : Feedback.where(email: email)).mailchimping +
      [creator_feedback].compact
  end

  def calculated_lists
    c_list = lists.dup
    if calculated_feedbacks.any? { |f| f.lead? }
      c_list << "organization"
    elsif mailchimp_organization_membership.present?
      c_list << "organization"
    end
    if user&.present?
      c_list << "individual" if user.payments.donation.any?
      c_list << "individual" if stolen_records_recovered.any?
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
    updated_interests << "donors" if user&.payments&.donation&.any?
    updated_interests << "recovered-bike-owners" if stolen_records_recovered.any?
    updated_interests.uniq.sort
  end
end
