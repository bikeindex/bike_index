# == Schema Information
#
# Table name: mailchimp_values
#
#  id           :bigint           not null, primary key
#  data         :jsonb
#  kind         :integer
#  list         :integer
#  name         :string
#  slug         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  mailchimp_id :string
#

# Mailchimp Values are the fields stored in Mailchimp
class MailchimpValue < ApplicationRecord
  LIST_ENUM = {
    organization: 0,
    individual: 1
  }.freeze
  KIND_ENUM = {
    interest_category: 0,
    interest: 1, # AKA groups
    tag: 2,
    merge_field: 3
  }.freeze

  validates_presence_of :slug, :list, :kind, :mailchimp_id
  validates_uniqueness_of :mailchimp_id, scope: %i[list kind]

  before_validation :set_calculated_attributes

  enum :list, LIST_ENUM
  enum :kind, KIND_ENUM

  def self.lists
    LIST_ENUM.keys.map(&:to_s)
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.slugify(str)
    slug = Slugifyer.slugify(str).tr("-", "_")
    # Make the slugs match organization kinds
    if slug == "school__university"
      "school"
    elsif slug == "law_enforcement__municipality"
      "law_enforcement"
    elsif slug == "other_kind_of_organization"
      "other"
    else
      slug
    end
  end

  def self.friendly_find(str, kind: nil, list: nil)
    values = kind.present? ? where(kind: kind) : self
    values = list.present? ? where(list: list) : values
    mailchimp_value = values.find_by_mailchimp_id(str)
    mailchimp_value ||= values.find_by_id(str) if str.is_a?(Integer) || str.match(/\A\d+\z/).present?
    mailchimp_value || values.find_by_slug(slugify(str))
  end

  def set_calculated_attributes
    self.data ||= {}
    self.mailchimp_id ||= if merge_field?
      data["tag"]
    else
      data["id"] || data["merge_id"]
    end
    self.name = calculated_name if calculated_name.present? # Mainly for specs
    self.slug = self.class.slugify(name)
  end

  private

  def calculated_name
    data&.dig("title") || data&.dig("name") || ""
  end
end
