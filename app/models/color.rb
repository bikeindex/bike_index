# == Schema Information
#
# Table name: colors
# Database name: primary
#
#  id         :integer          not null, primary key
#  display    :string(255)
#  name       :string(255)
#  priority   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Color < ApplicationRecord
  include AutocompleteHashable
  include FriendlyNameFindable

  # Added to make it possible to test processing colors. Is just Color.all.pluck(:name)
  ALL_NAMES = ["Black", "Blue", "Brown", "Green", "Orange", "Pink", "Purple", "Red",
    "Silver, gray or bare metal", "Stickers tape or other cover-up", "Teal", "White",
    "Yellow or Gold"].freeze

  has_many :bikes
  has_many :paints

  default_scope { order(:name) }
  scope :commonness, -> { order("priority ASC, name ASC") }

  validates_presence_of :name, :priority
  validates_uniqueness_of :name

  def self.black
    where(name: "Black", priority: 1, display: "#000").first_or_create
  end

  def self.select_options
    normalize = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]+/, "_") }
    translation_scope = [:activerecord, :select_options, name.underscore]

    pluck(:id, :name).map do |id, name|
      localized_name = I18n.t(normalize.call(name), scope: translation_scope)
      [localized_name, id]
    end
  end

  def self.friendly_find(n)
    # Use the FriendlyNameFindable version, then the first part of the string (for slug), then grasp at straws
    super ||
      where("lower(name) ILIKE ?", "#{n.to_s.downcase.strip}%").first ||
      where("lower(name) ILIKE ?", "%#{n.to_s.downcase.strip}%").first
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: "colors",
      priority: 1000,
      data: {
        priority: 1000,
        display: display,
        search_id: search_id
      }
    }
  end

  def search_id
    "c_#{id}"
  end

  def slug
    name.downcase.split(/\W+/).first
  end
end
