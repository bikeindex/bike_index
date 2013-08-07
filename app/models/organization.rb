class Organization < ActiveRecord::Base
  attr_accessible :available_invitation_count,
    :sent_invitation_count,
    :name,
    :short_name,
    :slug,
    :website,
    :paid,
    :default_bike_token_count,
    :is_a_bike_shop,
    :is_suspended,
    :locations_attributes

  acts_as_paranoid

  has_many :memberships, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :users, through: :memberships
  has_many :organization_invitations, dependent: :destroy

  has_many :locations, dependent: :destroy
  accepts_nested_attributes_for :locations, allow_destroy: true

  validates_presence_of :name, :default_bike_token_count, :short_name

  validates_uniqueness_of :slug, message: "Needs a unique slug"

  scope :bike_shops, where(is_a_bike_shop: true)

  before_save :set_slug
  def set_slug
    # if self.short_name
    # self.slug = self.short_name.gsub(/\s/, '_').gsub(/([^A-Za-z0-9_\-]+)/,'').downcase
    # else
      self.slug = Slugifyer.slugify(self.short_name)
    # end
  end
  # def set_slug
  #   self.slug = Slugifyer.slugify(self.name)
  # end

  # before_save :set_url
  # def set_url
  #   if self.website
  #     self.website = Urlifyer.urlify(self.website)
  #   end
  # end

  def suspended?
    is_suspended?
  end

  before_save :truncate_short_name
  def truncate_short_name
    self.short_name = self.short_name.truncate(15)
  end

  def last_billing_date
    return self.created_at unless self.invoices.any?
    return self.invoices.last.billing_period_end
  end

end
