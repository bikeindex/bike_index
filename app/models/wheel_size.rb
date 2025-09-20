# == Schema Information
#
# Table name: wheel_sizes
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
  validates :name, :priority, :description, :iso_bsd, presence: true
  validates :description, :iso_bsd, uniqueness: true
  has_many :bikes

  default_scope { order(:iso_bsd) }

  scope :commonness, -> { reorder("wheel_sizes.priority ASC, wheel_sizes.iso_bsd DESC") }

  def self.id_for_bsd(bsd)
    ws = where(iso_bsd: bsd.to_i).first
    ws&.id
  end

  def self.popularities
    %w[Standard Common Uncommon Rare]
  end

  def select_value
    "[#{iso_bsd}] #{description}"
  end

  def popularity
    WheelSize.popularities[priority - 1]
  end
end
