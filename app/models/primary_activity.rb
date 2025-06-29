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

  SPECIAL_SHORT_NAMES = {
    "road" => "road-biking",
    "track" => "track-racing"
  }.freeze

  belongs_to :primary_activity_family, class_name: "PrimaryActivity"

  has_many :primary_activity_flavors, class_name: "PrimaryActivity",
    foreign_key: :primary_activity_family_id
  has_many :bikes
  has_many :bike_versions

  validates_presence_of :name
  # NOTE: This class has something very similar to FriendlySlugFindable
  # But scopes the validation of uniqueness
  validates_uniqueness_of :name, scope: [:primary_activity_family_id], allow_nil: false
  validates_uniqueness_of :slug, scope: [:primary_activity_family_id], allow_nil: false

  before_validation :set_calculated_attributes
  after_create :assign_family_id_if_self

  scope :family, -> { where(family: true) }
  scope :flavor, -> { where(family: false) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :alphabetized, -> { order(Arel.sql("LOWER(name)")) }
  # top_level means that there isn't a family
  scope :top_level, -> { where("primary_activity_family_id = id") }
  scope :not_top_level, -> { where("primary_activity_family_id != id") }

  class << self
    def friendly_find(str)
      friendly_find_with_select(str, select_attrs: ["*"])
    end

    def friendly_find_id(str)
      friendly_find_with_select(str)&.id
    end

    # This returns just the id if it's
    def friendly_find_id_and_family_ids(str)
      return [] if str.blank?
      str.strip! if str.is_a?(String)
      if integer_string?(str)
        ids = ids_matching_family_id(str)
        ids = by_priority.where(id: str).pluck(:id) if ids.none?

        return ids.any? ? [str.to_i, ids] : []
      end

      result = friendly_find_with_select(str, select_attrs: %i[id primary_activity_family_id family])
      return [] if result.blank?

      # If the object that was found was a flavor, no need to search again
      # but if it's a family, search for the family ids
      ids = result.family ? ids_matching_family_id(result.id) : [result.id]
      [result.id, ids]
    end

    private

    def ids_matching_family_id(integer)
      by_priority.where(primary_activity_family_id: integer).pluck(:id)
    end

    def friendly_find_with_select(str, select_attrs: [:id])
      return nil if str.blank?
      str.strip! if str.is_a?(String)
      return by_priority.where(id: str).select(*select_attrs).first if integer_string?(str)
      # Special short slugs
      special_short_slug = SPECIAL_SHORT_NAMES[str.downcase]
      return where(slug: special_short_slug).select(*select_attrs).first if special_short_slug.present?

      by_priority.where(slug: Slugifyer.slugify(str)).select(*select_attrs).first ||
        by_priority.where("lower(name) = ?", str.downcase).select(*select_attrs).first ||
        by_priority.where("name ILIKE ?", "%#{str}%").select(*select_attrs).first
    end
  end

  def to_param
    slug
  end

  def flavor?
    !family?
  end

  def top_level?
    primary_activity_family_id == id
  end

  def display_name
    [family_display_name, name].compact.join(": ")
  end

  def display_name_search
    [family_display_name(include_skipped_family_name: true), name].compact.join(": ONLY ")
  end

  def family_name
    primary_activity_family&.name
  end

  def family_short_name
    primary_activity_family&.short_name
  end

  def short_name
    return "Road" if slug == "road-biking"
    return "Track" if slug == "track-racing"

    super
  end

  private

  def skip_family_display_name?
    %w[cyclocross gravel].include?(name.downcase)
  end

  def family_display_name(include_skipped_family_name: false)
    return nil if primary_activity_family.blank? || top_level?
    return nil if skip_family_display_name? && !include_skipped_family_name

    family_short_name
  end

  def set_calculated_attributes
    self.name = name&.strip
    self.slug ||= Slugifyer.slugify(name)
    self.priority ||= calculated_priority
    # If it doesn't have a family, assign primary_activity_family_id to its own ID, so it's searchable
    # EVEN if it's a flavor
    self.primary_activity_family_id = id if primary_activity_family.blank?
  end

  # After create, update with family id if it's blank
  def assign_family_id_if_self
    return if primary_activity_family_id.present?

    update(primary_activity_family_id: id)
  end

  def calculated_priority
    return calculated_family_priority if family?
    return primary_activity_family.priority - 100 if primary_activity_family.present?

    401
  end

  def calculated_family_priority
    prior_families = self.class.family
    prior_families = prior_families.where("id < ?", id) if id.present?

    490 - (prior_families.count * 10)
  end
end
