# frozen_string_literal: true

module Atoms
  module Admin
    module Badges
      module User
        class Component < ApplicationComponent
          KIND_LETTERS = {
            bike_shop: "BS",
            bike_advocacy: "V",
            law_enforcement: "P",
            school: "S",
            bike_manufacturer: "M",
            ambassador: "A",
            municipality: "MU"
          }.freeze

          def initialize(user:, full_text: false)
            @user = user
            @full_text = full_text
          end

          def render?
            badges.any?
          end

          private

          def banned?
            @user&.banned?
          end

          def banned_text
            return @banned_text if defined?(@banned_text)

            @banned_text = [
              "Banned",
              @user.user_ban.present? ? @user.user_ban.reason_humanized : nil
            ].compact.join(": ")
          end

          def email_banned?
            @email_bans ||= @user&.email_bans_active || []

            @email_bans.any?
          end

          def email_banned_text
            @email_bans.map { EmailBan.reason_humanized(it.reason) }.join(", ")
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

          def wrapper_class
            "tw:inline-flex tw:gap-1 #{"tw:gap-x-3" if @full_text}"
          end

          def badges
            @badges ||= [
              *user_badges,
              (badge("B", banned_text, :error) if banned?),
              (badge("EB", "Email Banned: #{email_banned_text}", :error) if email_banned?)
            ].compact
          end

          def user_badges
            return [] if @user&.id.blank?
            return [badge("S", "Superuser", :purple)] if @user.superuser?

            [
              (badge("D", "Donor", :success, link: ["payments", admin_payments_path(user_id: @user.id)]) if @user.donor?),
              (badge("M", "Member", :success, link: ["memberships", admin_memberships_path(user_id: @user.id)]) if @user.membership_active.present?),
              (badge(org_icon_text, org_full_text, :notice, link: [organization.name, admin_organization_path(organization)]) if organization.present?),
              (badge("R", "Recovered bike", :warning) if @user.recovered_records.limit(1).any?),
              (badge("P", "Promoted alert purchaser", :cyan, link: ["alerts", admin_theft_alerts_path(user_id: @user.id)]) if @user.theft_alert_purchaser?)
            ]
          end

          def badge(text, label, color, link: nil) = {text:, label:, color:, link:}

          def description(badge)
            return badge[:label] unless badge[:link]

            safe_join([badge[:label], link_to(*badge[:link], class: "twlink")], " - ")
          end
        end
      end
    end
  end
end
