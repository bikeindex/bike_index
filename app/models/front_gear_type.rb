# == Schema Information
#
# Table name: front_gear_types
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
class FrontGearType < ApplicationRecord
  include FriendlySlugFindable

  validates :name, :count, presence: true
  validates :name, uniqueness: true
  has_many :bikes

  scope :standard, -> { where(standard: true) }
  scope :internal, -> { where(internal: true) }

  def self.fixed
    where(name: "1", count: 1, internal: false, standard: true).first_or_create
  end
end
