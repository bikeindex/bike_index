# == Schema Information
#
# Table name: states
#
#  id           :integer          not null, primary key
#  abbreviation :string(255)
#  name         :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  country_id   :integer
#
# Indexes
#
#  index_states_on_country_id  (country_id)
#
class State < ApplicationRecord
  validates :country, presence: true
  validates :name, :abbreviation, uniqueness: true, presence: true

  belongs_to :country
  has_many :locations
  has_many :stolen_records

  default_scope { order(:name) }

  def self.friendly_find(str)
    return nil unless str.present?
    fuzzy_abbr_find(str) || where("lower(name) = ?", str.downcase.strip).first
  end

  def self.fuzzy_abbr_find(str)
    str && where("lower(abbreviation) = ?", str.downcase.strip).first
  end

  def self.valid_names
    StatesAndCountries.states.map { |s| s[:name] }
  end

  def to_combobox_display
    name
  end
end
