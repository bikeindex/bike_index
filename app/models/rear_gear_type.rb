# == Schema Information
#
# Table name: rear_gear_types
# Database name: primary
#
#  id         :integer          not null, primary key
#  count      :integer
#  internal   :boolean          default(FALSE), not null
#  name       :string(255)
#  slug       :string(255)
#  standard   :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class RearGearType < ApplicationRecord
  include FriendlySlugFindable

  MEMOIZE_FIXED = ENV["SKIP_MEMOIZE_STATIC_MODEL_RECORDS"].blank? # enable skipping for testing

  has_many :bikes

  validates_presence_of :name, :count
  validates_uniqueness_of :name

  scope :standard, -> { where(standard: true) }
  scope :internal, -> { where(internal: true) }

  def self.fixed
    return @fixed if MEMOIZE_FIXED && defined?(@fixed)

    @fixed = where(name: "Fixed", count: 1, internal: false).first_or_create
  end
end
