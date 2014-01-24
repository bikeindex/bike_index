class State < ActiveRecord::Base
  attr_accessible :name, :abbreviation, :country_id
  validates_presence_of :name, :abbreviation, :country_id
  validates_uniqueness_of :name, :abbreviation

  belongs_to :country 
  has_many :locations
  has_many :stolen_records

  default_scope order(:name)

  def self.fuzzy_abbr_find(n)
    if !n.blank?
      self.find(:first, :conditions => [ "lower(abbreviation) = ?", n.downcase.strip ])
    else
      nil
    end
  end

end
