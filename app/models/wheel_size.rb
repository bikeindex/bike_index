# == Schema Information
#
# Table name: wheel_sizes
# Database name: primary
#
#  id          :integer          not null, primary key
#  description :string(255)
#  iso_bsd     :integer
#  name        :string(255)
#  priority    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class WheelSize < ApplicationRecord
  enum :priority, {standard: 1, common: 2, uncommon: 3, rare: 4}
  has_many :bikes

  validates_presence_of :name, :priority, :description, :iso_bsd
  validates_uniqueness_of :description, :iso_bsd

  default_scope { order(:iso_bsd) }

  scope :commonness, -> { reorder("wheel_sizes.priority ASC, wheel_sizes.iso_bsd DESC") }

  def self.id_for_bsd(bsd)
    ws = where(iso_bsd: bsd.to_i).first
    ws&.id
  end

  def self.popularities
    priorities.keys.map(&:titleize)
  end

  def select_value
    "[#{iso_bsd}] #{description}"
  end

  def popularity
    priority.titleize
  end
end
