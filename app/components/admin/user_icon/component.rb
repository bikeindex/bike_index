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
      @tags = compute_tags
    end

    def render?
      @tags.any? || banned? || email_banned?
    end

    private

    def banned?
      @user&.banned?
    end

    def banned_text
      return @banned_text if defined?(@banned_text)

      @banned_text = [
        "Banned",
        @user.user_ban.present? ? @user.user_ban.reason.humanize : nil
      ].compact.join(": ")
    end

    def email_banned?
      @email_bans ||= @user&.email_bans_active || []

      @email_bans.any?
    end

    def email_banned_text
      @email_bans.map { EmailBan.reason_humanized(it.reason) }.join(", ")
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
        organization.paid_money? ? "$" : nil,
        "O-",
        KIND_LETTERS[organization.kind.to_sym] || "O"
      ].compact.join("")
    end

    def org_full_text
      [
        organization.paid_money? ? "Paid" : nil,
        "organization member -",
        Organization.kind_humanized(organization.kind)
      ].compact.join(" ")
    end

    def icon_classes(variant = nil)
      base = "tw:ml-1 tw:inline-block tw:text-white tw:text-[75%] tw:font-extrabold tw:px-1 tw:py-0.5 tw:border tw:border-gray-300 tw:leading-none tw:rounded-lg tw:cursor-default"

      bg = case variant
      when :donor then "tw:bg-emerald-500"
      when :organization_role then "tw:bg-blue-600"
      when :superuser then "tw:bg-purple-800"
      when :recovery then "tw:bg-amber-400"
      when :theft_alert then "tw:bg-cyan-600"
      when :banned then "tw:bg-red-500"
      when :email_banned then "tw:bg-red-400"
      end

      [base, bg].compact.join(" ")
    end
  end
end
