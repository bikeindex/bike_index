class ContentTag < ApplicationRecord
  include FriendlySlugFindable
  has_many :blog_content_tags
  has_many :blogs, through: :blog_content_tags

  scope :commonness, -> { order("priority ASC, name ASC") }
  scope :name_ordered, -> { order(arel_table["name"].lower) }

  before_save :set_calculated_attributes

  def set_calculated_attributes
    self.priority ||= 1
  end
end
