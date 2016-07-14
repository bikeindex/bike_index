class WheelSize < ActiveRecord::Base
  def old_attr_accessible 
    %w(name priority description iso_bsd).map(&:to_sym).freeze
  end

  validates_presence_of :name, :priority, :description, :iso_bsd
  validates_uniqueness_of :description, :iso_bsd
  has_many :bikes

  default_scope { order(:iso_bsd) }
  scope :commonness, -> { order("priority ASC, iso_bsd DESC") }

  def self.id_for_bsd(bsd)
    ws = where(iso_bsd: bsd.to_i).first
    ws && ws.id
  end

  def select_value
    "[#{iso_bsd}] #{description}"
  end

  def self.popularities
    ["Standard", "Common", "Uncommon", "Rare"]
  end

  def popularity
    WheelSize.popularities[priority-1]
  end
end
