# == Schema Information
#
# Table name: countries
#
#  id         :integer          not null, primary key
#  iso        :string(255)
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Country < ApplicationRecord
  UNITED_STATES_ID = Rails.env.test? ? nil : 230
  CANADA_ID = Rails.env.test? ? nil : 38

  validates_presence_of :name
  validates_uniqueness_of :name, :iso

  has_many :stolen_records
  has_many :locations

  class << self
    def select_options
      pluck(:id, :iso).map do |id, iso|
        [I18n.t(iso, scope: :countries), id]
      end
    end

    def friendly_find(name_or_iso)
      name_or_iso = name_or_iso.to_s.strip.downcase
      return if name_or_iso.blank?
      return united_states if name_or_iso.in? %w[us usa]

      find_by("lower(name) = ? or lower(iso) = ?", name_or_iso, name_or_iso)
    end

    def united_states
      where(name: "United States", iso: "US").first_or_create
    end

    def canada
      where(name: "Canada", iso: "CA").first_or_create
    end

    # For testing, look it up, otherwise use static
    def united_states_id
      UNITED_STATES_ID || Country.united_states.id
    end

    # For testing, look it up, otherwise use static
    def canada_id
      CANADA_ID || Country.canada.id
    end

    def netherlands
      where(name: "Netherlands", iso: "NL").first_or_create
    end

    def valid_names
      StatesAndCountries.countries.map { |c| c[:name] }
    end
  end

  def united_states?
    iso.upcase == "US"
  end

  def default?
    united_states?
  end

  # consistency with state
  def abbreviation
    iso
  end
end
