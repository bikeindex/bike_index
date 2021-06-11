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

  enum status: STATUS_ENUM

  before_validation :set_calculated_attributes
  after_commit :update_association_and_mailchimp, if: :persisted?

  def self.find_or_create_for(obj)
    if obj.is_a?(User)
      where(user_id: obj.id).first || where(email: obj.confirmed_emails).first ||
        create(user: obj)
    else
      fail "Unable to create mailchimp data for #{obj}"
    end
  end

  def audiences
    data["audiences"] || []
  end


  def set_calculated_attributes
    self.email = user.email if user.present?
    @previous_data ||= data
    self.data = calculated_data
    self.status = calculated_status
  end

  def update_association_and_mailchimp
    calculated_feedbacks.where(mailchimp_datum_id: nil).each { |f|
      f.update(mailchimp_datum_id: id)
    }
    return true if @previous_data == data
    UpdateMailchimpDatumWorker.perform_async(id)
  end

  def ensure_subscription_required
    return true unless no_subscription_required?
    errors.add(:base, "No mailchimp subscription required, so not creating")
  end

  def calculated_data
    {
      audiences: calculated_audiences
    }
  end

  def calculated_status
    return status if status.present? &&
      !%w[subscribed no_subscription_required].include?(status)
    return "no_subscription_required" if audiences.none?
    "subscribed"
  end

  def calculated_feedbacks
    user.present? ? user.feedbacks : Feedback.where(email: email)
  end

  def calculated_audiences
    aud = []
    aud += calculated_feedbacks.leads.pluck(:kind)
    aud
  end
end
