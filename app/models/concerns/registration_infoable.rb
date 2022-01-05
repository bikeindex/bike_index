# frozen_string_literal: true

module RegistrationInfoable
  extend ActiveSupport::Concern

  REGISTRATION_INFO_KEYS = %w[
    organization_affiliation
    student_id
    phone
    bike_sticker
    city
    country
    staten
    street
    zipcode
    latitude
    longitude
  ].freeze

  class_methods do
    def org_id_for_org(org = nil)
      return nil if org.blank?
      is_a?(Organization) ? org.id : Organization.friendly_find_id(org)
    end
  end

  def registration_info_uniq_keys
    [reg_info[student_id_key].present? ? "student_id" : nil,
     reg_info[student_id_key].present? ? "organization_affiliation" : nil].compact
  end

  def student_id_key(org = nil)
    return "student_id" if reg_info.key?("student_id")
    return reg_info.keys.find { |k| k.start_with?(/student_id/) } if org.blank?
    ["student_id", self.class.org_id_for_org(org)].compact.join("_")
  end

  def student_id(org = nil)
    reg_info[student_id_key(org)]
  end

  def organization_affiliation_key(org = nil)
    return "organization_affiliation" if reg_info.key?("organization_affiliation")
    return reg_info.keys.find { |k| k.start_with?(/organization_affiliation/) } if org.blank?
    ["organization_affiliation", self.class.org_id_for_org(org)].compact.join("_")
  end

  def organization_affiliation(org = nil)
    reg_info[organization_affiliation_key(org)]
  end

  def update_registration_information(key, value)
    update(registration_info: registration_info.merge(key => value))
    value
  end

  def organization_affiliation=(val, org = nil)
    update_registration_information(organization_affiliation_key(org), val)
  end

  def student_id=(val, org = nil)
    update_registration_information(student_id_key(org), val)
  end

  def address_hash
    reg_info.slice("street", "city", "state", "zipcode", "state", "country")
      .with_indifferent_access
  end

  private

  # Only internal, nil protection. Only should be nil when unsaved
  def reg_info
    registration_info || {}
  end
end
