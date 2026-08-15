# frozen_string_literal: true

module Admin
  module OrganizationForm
    module Wrapper
      class Component < ApplicationComponent
        AMBASSADOR_TARGETS = {data: {"admin--organization-form-target": "ambassadorLabel"},
                              input_data: {"admin--organization-form-target": "ambassadorField"}}.freeze

        def initialize(form_builder:, organization:, current_user:)
          @form_builder = form_builder
          @organization = organization
          @current_user = current_user
        end

        private

        def checkbox_field(attribute, label, note: nil, ambassador: false)
          render(UI::Forms::Checkbox::Component.new(form_builder: @form_builder, attribute:,
            label: label_with_note(label, note), class_name: "tw:mb-4", **(ambassador ? AMBASSADOR_TARGETS : {})))
        end

        def label_with_note(text, note)
          return text if note.blank?

          safe_join([text, tag.small(note, class: "less-strong")], " ")
        end

        def read_only_field(label, value)
          tag.div(class: "tw:mb-4") { tag.label(label, class: "twlabel") + tag.p(value, class: "less-strong") }
        end

        def kind_option_tags
          options_for_select(Organization.kinds.map { |kind| [Organization.kind_humanized(kind), kind] },
            selected: @organization.kind)
        end

        def parent_organization_options
          Organization.with_enabled_feature_slugs("child_organizations").pluck(:name, :id)
        end

        def auto_user_emails
          emails = @organization.users.pluck(:email)
          emails.any? ? emails : [ENV["AUTO_ORG_MEMBER"]]
        end

        def embedable_email = @organization.auto_user&.email

        def manual_pos_kind_entries
          [{value: "not_set", label: "not set"}] +
            Organization.pos_kinds.map { |pos_kind| {value: pos_kind, label: pos_kind.humanize.gsub("pos", "").strip} }
        end

        def selected_manual_pos_kind
          @organization.manual_pos_kind.presence || "not_set"
        end
      end
    end
  end
end
