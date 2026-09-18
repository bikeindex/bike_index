module OrgServices
  module RegistrationFields
    extend Functionable

    # Shown with the owner rather than in registration information
    OWNER_ACCESS_REG_FIELDS = %w[reg_organization_affiliation reg_student_id].freeze

    # [label, value] for each of reg_fields the organization collects
    def rows(bike:, organization:, reg_fields:)
      (reg_fields & organization.additional_registration_fields).map do |reg_field|
        [label(organization:, reg_field:), value(bike:, organization:, reg_field:)]
      end
    end

    def value(bike:, organization:, reg_field:)
      bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field)
      case bike_attr
      when "organization_affiliation" then bike.organization_affiliation(organization)&.humanize
      when "student_id" then bike.student_id(organization)
      else bike.send(bike_attr)
      end
    end

    def label(organization:, reg_field:)
      custom = organization.registration_field_labels&.dig(reg_field)
      return Binxtils::InputNormalizer.sanitize(custom) if custom.present?

      OrganizationFeature.reg_field_to_bike_attrs(reg_field).humanize(keep_id_suffix: true)
    end
  end
end
