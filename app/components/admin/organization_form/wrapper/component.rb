# frozen_string_literal: true

module Admin
  module OrganizationForm
    module Wrapper
      class Component < ApplicationComponent
        def initialize(form_builder:, organization:, current_user:, embedable_email: nil)
          @form_builder = form_builder
          @organization = organization
          @current_user = current_user
          @embedable_email = embedable_email
        end

        private

        def kind_options
          Organization.kinds.map { |kind| [Organization.kind_humanized(kind), kind] }
        end

        def parent_organization_options
          Organization.with_enabled_feature_slugs("child_organizations").pluck(:name, :id)
        end

        def auto_user_emails
          emails = @organization.users.pluck(:email)
          emails.any? ? emails : [ENV["AUTO_ORG_MEMBER"]]
        end

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
