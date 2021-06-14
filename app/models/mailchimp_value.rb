class MailchimpValue < ApplicationRecord
  LIST_ENUM = {
    organization: 0,
    individual: 1,
    from_bike_index: 2
  }
  KIND_ENUM = {
    interest_category: 0,
    interest: 1, # AKA groups
    tag: 2
  }

  validates_presence_of :slug
  validates_uniqueness_of :mailchimp_id, scope: %i[list kind]

  enum list: LIST_ENUM
  enum kind: KIND_ENUM

  def self.friendly_find(str, kind, list = nil)
    values = where(kind: kind)
    values = values.where(list: list) if list.present?
    values.find_by_slug(str)
  end

  def display_name

  end
end
