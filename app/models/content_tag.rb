# == Schema Information
#
# Table name: content_tags
# Database name: primary
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  priority    :integer
#  slug        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class ContentTag < ApplicationRecord
  include FriendlySlugFindable

  has_many :blog_content_tags, dependent: :destroy
  has_many :blogs, through: :blog_content_tags

  scope :commonness, -> { order("priority DESC, name ASC") }
  scope :name_ordered, -> { order(arel_table["name"].lower) }

  before_save :set_calculated_attributes

  def self.matching_ids(str_or_array)
    return [] if str_or_array.blank?

    array = str_or_array.is_a?(Array) ? str_or_array : str_or_array.split(/,|\n/)
    array.map { |s| friendly_find_id(s) }.compact.uniq
  end

  def self.matching(str_or_array)
    where(id: matching_ids(str_or_array))
  end

  def set_calculated_attributes
    self.priority ||= 1
  end
end
