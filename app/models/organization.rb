class Organization < ActiveRecord::Base
  attr_accessible :available_invitation_count,
    :sent_invitation_count,
    :name,
    :short_name,
    :slug,
    :website,
    :default_bike_token_count,
    :show_on_map,
    :is_suspended,
    :locations_attributes,
    :embedable_user_email,
    :embedable_user_id

  attr_accessor :embedable_user_email
  acts_as_paranoid

  has_many :memberships, dependent: :destroy
  has_many :organization_deals, dependent: :destroy
  has_many :users, through: :memberships
  has_many :organization_invitations, dependent: :destroy
  belongs_to :embedable_user, class_name: "User"

  has_many :locations, dependent: :destroy
  accepts_nested_attributes_for :locations, allow_destroy: true

  validates_presence_of :name, :default_bike_token_count, :short_name

  validates_uniqueness_of :slug, message: "Needs a unique slug"

  default_scope order(:name)

  scope :shown_on_map, where(show_on_map: true)

  def to_param
    slug
  end

  before_save :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.short_name)
  end


  before_save :set_embedable_user
  def set_embedable_user
    if self.embedable_user_email.present?
      u = User.fuzzy_email_find(embedable_user_email)
      self.embedable_user_id = u.id if u.is_member_of?(self)
    end
  end

  def suspended?
    is_suspended?
  end

  before_save :truncate_short_name
  def truncate_short_name
    self.short_name = self.short_name.truncate(15)
  end

end
