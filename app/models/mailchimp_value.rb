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

  validates_presence_of :slug, :list, :kind, :mailchimp_id
  validates_uniqueness_of :mailchimp_id, scope: %i[list kind]

  before_validation :set_calculated_attributes

  enum list: LIST_ENUM
  enum kind: KIND_ENUM

  def self.lists
    LIST_ENUM.keys.map(&:to_s)
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.friendly_find(str)
    find_by_mailchimp_id(str) || find_by_slug(str) || find_by_id(str)
  end

  def display_name
    data&.dig("title") || data&.dig("name") || ""
  end

  def set_calculated_attributes
    self.data ||= {}
    self.mailchimp_id ||= data["id"]
    self.slug ||= Slugifyer.slugify(display_name)
  end
end
