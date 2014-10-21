class Country < ActiveRecord::Base
  attr_accessible :name, :iso
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :iso
  has_many :stolen_records
  has_many :locations

  def self.fuzzy_iso_find(n)
    n = 'us' if n.match(/usa/i)
    if !n.blank?
      self.find(:first, conditions: [ "lower(iso) = ?", n.downcase.strip ])
    else
      nil
    end
  end

end
