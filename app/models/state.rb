# == Schema Information
#
# Table name: states
# Database name: primary
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
  belongs_to :country
  has_many :locations
  has_many :stolen_records

  validates :country, presence: true
  validates :name, :abbreviation, uniqueness: true, presence: true

  default_scope { order(:name) }

  class << self
    def friendly_find(str, country_id: nil)
      str = Binxtils::InputNormalizer.string(str) if str.is_a?(String)
      return nil if str.blank?

      matches = country_id.present? ? where(country_id:) : all
      matches.fuzzy_abbr_find(str) || matches.where("lower(name) = ?", str.downcase).first
    end

    def fuzzy_abbr_find(str)
      str = Binxtils::InputNormalizer.string(str) if str.is_a?(String)
      str.present? && where("lower(abbreviation) = ?", str.downcase).first
    end

    def valid_names
      StatesAndCountries.states.map { |s| s[:name] }
    end

    def united_states
      where(country_id: Country.united_states_id)
    end
  end
end
