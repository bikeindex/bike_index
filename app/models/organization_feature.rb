# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_features
#
#  id            :integer          not null, primary key
#  amount_cents  :integer
#  currency_enum :integer
#  description   :text
#  details_link  :string
#  feature_slugs :text             default([]), is an Array
#  kind          :integer          default("standard")
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class OrganizationFeature < ApplicationRecord
  include Amountable
  include Currencyable

  KIND_ENUM = {standard: 0, standard_one_time: 1, custom: 2, custom_one_time: 3}.freeze
  # Organizations have enabled_feature_slugs as an array attribute to track which features should be enabled
  # Every feature slug that is used in the code should be in this array
  # Only slugs that are used in the code should be in this array

  # NOTE: reg_bike_sticker is automatically added if the org has stickers, no need to manually add
  REG_FIELDS = %w[
    reg_address
    reg_bike_sticker
    reg_extra_registration_number
    reg_organization_affiliation
    reg_phone
    reg_student_id
  ].freeze

  BIKE_ACTIONS = %w[
    additional_registrations_information
    impound_bikes
    parking_notifications
    unstolen_notifications
  ].freeze

  # NOTE: impound_bikes_public is automatically added if the org configures, no need to manually addz
  EXPECTED_SLUGS = (%w[
    avery_export
    bike_search
    bike_stickers
    bike_stickers_user_editable
    child_organizations
    claimed_ownerships
    credibility_badges
    csv_exports
    customize_emails
    graduated_notifications
    hot_sheet
    impound_bikes_locations
    impound_bikes_public
    model_audits
    no_address
    official_manufacturer
    organization_stolen_message
    passwordless_users
    regional_bike_counts
    require_student_id
    show_bulk_import
    show_bulk_import_impound
    show_bulk_import_stolen
    show_multi_serial
    show_partial_registrations
    show_recoveries
    skip_ownership_email
  ] + BIKE_ACTIONS + REG_FIELDS).freeze

  has_many :invoice_organization_features
  has_many :invoices, through: :invoice_organization_features

  validates_uniqueness_of :name
  validates :currency, presence: true

  enum :kind, KIND_ENUM

  after_commit :update_invoices

  scope :recurring, -> { where(kind: %w[standard custom]) }
  scope :upfront, -> { where(kind: %w[standard_upfront custom_upfront]) }
  scope :name_ordered, -> { order(arel_table["name"].lower) }
  scope :has_feature_slugs, -> { where.not(feature_slugs: []) }

  class << self
    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    # used by organization right now, but might be useful in other places
    def matching_slugs(slugs)
      slug_array = slugs.is_a?(Array) ? slugs : slugs.split(" ").reject(&:blank?)
      matching_slugs = EXPECTED_SLUGS & slug_array
      matching_slugs.any? ? matching_slugs : nil
    end

    def reg_field_to_bike_attrs(reg_field)
      reg_field.to_s.gsub("reg_", "")
    end

    def reg_fields
      REG_FIELDS
    end

    def reg_fields_with_customizable_labels
      # Can't rename bike_stickers
      %w[owner_email] + reg_fields - %w[reg_bike_sticker]
    end

    def reg_fields_organization_uniq
      %w[reg_organization_affiliation reg_student_id]
    end

    # These are attributes that add fields to admin organization edit
    def with_admin_organization_attributes
      reg_fields_with_customizable_labels +
        %w[regional_bike_counts passwordless_users graduated_notifications organization_stolen_message]
    end

    def feature_slugs
      pluck(:feature_slugs).flatten.uniq
    end
  end

  # TODO: migrate currency to currency_str then currency_enum
  def currency_name
    currency
  end

  def has_feature_slugs?
    feature_slugs.any?
  end

  def one_time?
    standard_one_time? || custom_one_time?
  end

  def recurring?
    !one_time?
  end

  def locked?
    feature_slugs.any? && invoices.active.any?
  end

  def feature_slugs_string
    feature_slugs.join(", ")
  end

  # We only want to store features that are used in the code. Some features overlap - e.g. there are packages that apply multiple features
  # So check for matches with the EXPECTED_SLUGS which tracks which features we're using
  def feature_slugs_string=(val)
    self.feature_slugs = val.split(",").reject(&:blank?).map do |str|
      fslug = str.downcase.strip
      EXPECTED_SLUGS.include?(fslug) ? fslug : nil
    end.compact
  end

  # Trigger an update to invoices which will, in turn, update the associated organizations
  def update_invoices
    invoices.each { |i| i.update(updated_at: Time.current) }
  end
end
