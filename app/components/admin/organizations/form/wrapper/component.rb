# frozen_string_literal: true

module Admin
  module Organizations
    module Form
      module Wrapper
        class Component < ApplicationComponent
          AMBASSADOR_TARGETS = {data: {"admin--organization-form-target": "ambassadorLabel"},
                                input_data: {"admin--organization-form-target": "ambassadorField"}}.freeze

          def initialize(form_builder:, current_user:)
            @form_builder = form_builder
            @organization = form_builder.object
            @current_user = current_user
          end

          private

          def checkbox_field(attribute, label, note: nil, ambassador: false)
            render(UI::Forms::Checkbox::Component.new(form_builder: @form_builder, attribute:,
              label: label_with_note(label, note), class_name: "tw:mb-4", **(ambassador ? AMBASSADOR_TARGETS : {})))
          end

          # The target goes on the column, since UI::Forms::Group renders the label itself
          def ambassador_group(attribute)
            tag.div(class: "col-md-6", data: AMBASSADOR_TARGETS[:data]) do
              render(UI::Forms::Group::Component.new(form_builder: @form_builder, attribute:,
                html_options: {data: AMBASSADOR_TARGETS[:input_data]}))
            end
          end

          def label_with_note(text, note)
            return text if note.blank?

            safe_join([text, tag.small(note, class: "less-strong")], " ")
          end

          # Not a UI::Forms::Group - there's no control here, and Group always marks one
          # required or optional
          def read_only_field(label, value, note: nil)
            tag.div(class: "tw:mb-4") do
              tag.label(label_with_note(label, note), class: "twlabel") + tag.p(value, class: "less-strong")
            end
          end

          def kind_option_tags
            options_for_select(Organization.kinds.map { |kind| [Organization.kind_humanized(kind), kind] },
              selected: @organization.kind)
          end

          def parent_organization_options
            Organization.with_enabled_feature_slugs("child_organizations").pluck(:name, :id)
          end

          def auto_user_emails = @organization.users.pluck(:email).presence || [ENV["AUTO_ORG_MEMBER"]]

          def embedable_email = @organization.auto_user&.email

          # A location the "Add a location" link just cloned has neither set
          def blank_location_attrs = {organization_id: @organization.id, name: @organization.name}

          def manual_pos_kind_entries
            [{value: "not_set", label: "not set"}] +
              Organization.pos_kinds.map { |pos_kind| {value: pos_kind, label: pos_kind.humanize.gsub("pos", "").strip} }
          end

          def selected_manual_pos_kind = @organization.manual_pos_kind.presence || "not_set"
        end
      end
    end
  end
end
