# == Schema Information
#
# Table name: primary_activities
#
#  id                         :bigint           not null, primary key
#  family                     :boolean
#  name                       :string
#  priority                   :integer
#  slug                       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  primary_activity_family_id :bigint
#
# Indexes
#
#  index_primary_activities_on_primary_activity_family_id  (primary_activity_family_id)
#
class PrimaryActivity < ApplicationRecord
  include FriendlyNameFindable
  include ShortNameable

  belongs_to :primary_activity_family, class_name: "PrimaryActivity"

  has_many :primary_activity_flavors, class_name: "PrimaryActivity",
    foreign_key: :primary_notification_id
  has_many :bikes
  has_many :bike_versions

  validates_presence_of :name
  # NOTE: This class has something very similar to FriendlySlugFindable
  # But scopes the validation of uniqueness
  validates_uniqueness_of :name, scope: [:primary_activity_family_id], allow_nil: false
  validates_uniqueness_of :slug, scope: [:primary_activity_family_id], allow_nil: false

  before_validation :set_calculated_attributes

  scope :family, -> { where(family: true) }
  scope :flavor, -> { where(family: false) }
  scope :by_priority, -> { order(priority: :desc) }

  class << self
    def friendly_find(n)
      return nil if n.blank?
      return by_priority.where(id: n).first if n.is_a?(Integer) || n.strip.match(/\A\d+\z/).present?
      by_priority.find_by_slug(Slugifyer.slugify(n)) ||
        by_priority.where("lower(name) = ?", n.downcase.strip).first
    end

    def friendly_find_id(str)
      o = friendly_find(str)
      o.present? ? o.id : nil
    end
  end

  def to_param
    slug
  end

  def flavor?
    !family?
  end

  def display_name
    [name, family_display_name].compact.join(" ")
  end

  def family_name
    primary_activity_family&.name
  end

  def family_short_name
    primary_activity_family&.short_name
  end

  private

  def skip_family_display_name?
    %w[gravel cyclocross].include?(name.downcase)
  end

  def family_display_name
    return nil if skip_family_display_name? || primary_activity_family.blank?

    "(#{family_short_name})"
  end

  def set_calculated_attributes
    self.name = name&.strip
    self.slug ||= Slugifyer.slugify(name)
    self.priority = calculated_priority
  end

  def calculated_priority
    return calculated_family_priority if family?
    return primary_activity_family.priority - 50 if primary_activity_family.present?

    401
  end

  def calculated_family_priority
    prior_families = self.class.family
    prior_families = prior_families.where("id < ?", id) if id.present?

    495 - (prior_families.count * 5)
  end
end
