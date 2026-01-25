# frozen_string_literal: true

module Admin::UserIcon
  class Component < ApplicationComponent
    KIND_LETTERS = {
      bike_shop: "BS",
      bike_advocacy: "V",
      law_enforcement: "P",
      school: "S",
      bike_manufacturer: "M",
      ambassador: "A"
    }.freeze

    def initialize(user:, full_text: false)
      @user = user
      @full_text = full_text
    end

    def render?
      tags.any?
    end

    private

    def tags
      @tags ||= compute_tags
    end

    def compute_tags
      return [] if @user&.id.blank?
      return [:superuser] if @user.superuser?

      result = []
      result << :donor if @user.donor?
      result << :member if @user.membership_active.present?
      result << :recovery if @user.recovered_records.limit(1).any?
      result << :theft_alert if @user.theft_alert_purchaser?
      result << :organization_role if organization.present?
      result
    end

    def organization
      @organization ||= @user&.organization_prioritized
    end

    def org_icon_text
      [
        organization.paid? ? "$" : nil,
        "O ",
        KIND_LETTERS[organization.kind.to_sym] || "O"
      ].compact.join("")
    end

    def org_full_text
      [
        organization.paid? ? "Paid" : nil,
        "organization member -",
        Organization.kind_humanized(organization.kind)
      ].compact.join(" ")
    end
  end
end
