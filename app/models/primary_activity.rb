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
  validates_uniqueness_of :name, :slug

  before_create :set_slug

  scope :priority, -> { order(:priority) }

  class << self
    # NOTE: This class is very similar to FriendlySlugFindable, but slightly different
    def friendly_find(n)
      return nil if n.blank?
      return priority_ordered.where(id: n).first if n.is_a?(Integer) || n.strip.match(/\A\d+\z/).present?
      priority_ordered.find_by_slug(Slugifyer.slugify(n)) ||
        priority_ordered.where("lower(name) = ?", n.downcase.strip).first
    end

    def friendly_find_id(str)
      o = friendly_find(str)
      o.present? ? o.id : nil
    end
  end

  def to_param
    slug
  end

  def set_slug
    self.name = name&.strip
    self.slug ||= Slugifyer.slugify(name)
  end

  def flavor?
    !family?
  end
end
