class State < ActiveRecord::Base
  validates_presence_of :name, :abbreviation, :country_id
  validates_uniqueness_of :name, :abbreviation

  belongs_to :country
  has_many :locations
  has_many :stolen_records

  default_scope { order(:name) }

  def self.fuzzy_find(str)
    return nil unless str.present?
    fuzzy_abbr_find(str) || where("lower(name) = ?", str.downcase.strip).first
  end

  def self.fuzzy_abbr_find(str)
    str && where("lower(abbreviation) = ?", str.downcase.strip).first
  end
end
