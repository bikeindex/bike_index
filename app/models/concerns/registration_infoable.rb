# frozen_string_literal: true

module RegistrationInfoable
  extend ActiveSupport::Concern

  LOCATION_KEYS = %w[city country state street zipcode latitude longitude].freeze

  # Currently not used, keeping it around for reference
  # REGISTRATION_INFO_KEYS = %w[
  #   organization_affiliation
  #   student_id
  #   phone
  #   bike_sticker
  #   city
  #   country
  #   state
  #   street
  #   zipcode
  #   latitude
  #   longitude
  # ].freeze

  class_methods do
    def org_id_for_org(org = nil)
      return nil if org.blank?

      is_a?(Organization) ? org.id : Organization.friendly_find_id(org)
    end

    def with_student_id(org)
      where("(registration_info -> 'student_id') is not null OR (registration_info -> 'student_id_#{org_id_for_org(org)}') is not null")
    end

    def with_organization_affiliation(org)
      where("(registration_info -> 'organization_affiliation') is not null OR (registration_info -> 'organization_affiliation_#{org_id_for_org(org)}') is not null")
    end
  end

  def registration_info_uniq_keys
    [reg_info[student_id_key].present? ? "student_id" : nil,
      reg_info[student_id_key].present? ? "organization_affiliation" : nil].compact
  end

  # Accepts organization or organization.id
  def student_id_key(org = nil)
    # If org is passed, first priority is the key with the matching org_id
    if org.present?
      key = ["student_id", self.class.org_id_for_org(org)].compact.join("_")
      return key if reg_info.key?(key)
    end
    return "student_id" if reg_info.key?("student_id")
    return nil if org.present?

    reg_info.keys.find { |k| k.start_with?("student_id") } || "student_id"
  end

  # Accepts organization or organization.id
  def student_id(org = nil)
    reg_info[student_id_key(org)]
  end

  # Accepts organization or organization.id
  def organization_affiliation_key(org = nil)
    # If org is passed, first priority is the key with the matching org_id
    if org.present?
      key = ["organization_affiliation", self.class.org_id_for_org(org)].compact.join("_")
      return key if reg_info.key?(key)
    end
    return "organization_affiliation" if reg_info.key?("organization_affiliation")
    return nil if org.present?

    reg_info.keys.find { |k| k.start_with?("organization_affiliation") } || "organization_affiliation"
  end

  # Accepts organization or organization.id
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

  private

  # Only internal, nil protection. Only should be nil when unsaved
  def reg_info
    registration_info || {}
  end
end
