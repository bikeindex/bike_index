class ContentTag < ApplicationRecord
  include FriendlySlugFindable

  scope :commonness, -> { order("priority ASC, name ASC") }
  scope :name_ordered, -> { order(arel_table["name"].lower) }

  before_save :set_calculated_attributes

  def set_calculated_attributes
    self.priority ||= 1
  end
end
