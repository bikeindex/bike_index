# frozen_string_literal: true

module RegistrationInfoable
  extend ActiveSupport::Concern

  # Currently not used, keeping it around for reference
  REGISTRATION_INFO_KEYS = %w[
    organization_affiliation
    student_id
    phone
    bike_sticker
    city
    country
    state
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

    def with_student_id(org)
      where("(registration_info -> 'student_id') is not null OR (registration_info -> 'student_id_#{org_id_for_org(org)}') is not null")
    end

    def with_organization_affiliation(org)
      where("(registration_info -> 'organization_affiliation') is not null OR (registration_info -> 'organization_affiliation_#{org_id_for_org(org)}') is not null")
    end

    def clean_registration_info(reg_info, org_ids = nil)
      # skip cleaning if it's blank
      return {} if reg_info.blank?
      # The only place user_name comes from, other than a user setting it themselves, is bulk_import
      reg_info["phone"] = Phonifyer.phonify(reg_info["phone"])
      # bike_code should be renamed bike_sticker
      if reg_info["bike_code"].present?
        reg_info["bike_sticker"] = reg_info.delete("bike_code")
      end
      (org_ids || []).each do |org_id|
        # TODO: post #2121 delete? (eg reg_info.delete("student_id"))
        # ... Might not work with nested organizations, etc
        if reg_info["student_id"].present?
          reg_info["student_id_#{org_id}"] = reg_info["student_id"]
        end
        if reg_info["organization_affiliation"].present?
          reg_info["organization_affiliation_#{org_id}"] = reg_info["organization_affiliation"]
        end
      end
      reg_info.reject { |_k, v| v.blank? }
    end
  end

  def registration_info_uniq_keys
    [reg_info[student_id_key].present? ? "student_id" : nil,
     reg_info[student_id_key].present? ? "organization_affiliation" : nil].compact
  end

  # Accepts organization or organization.id
  def student_id_key(org = nil)
    return "student_id" if reg_info.key?("student_id")
    return reg_info.keys.find { |k| k.start_with?(/student_id/) } if org.blank?
    ["student_id", self.class.org_id_for_org(org)].compact.join("_")
  end

  # Accepts organization or organization.id
  def student_id(org = nil)
    reg_info[student_id_key(org)]
  end

  # Accepts organization or organization.id
  def organization_affiliation_key(org = nil)
    return "organization_affiliation" if reg_info.key?("organization_affiliation")
    return reg_info.keys.find { |k| k.start_with?(/organization_affiliation/) } if org.blank?
    ["organization_affiliation", self.class.org_id_for_org(org)].compact.join("_")
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
