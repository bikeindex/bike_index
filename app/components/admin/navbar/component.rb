# frozen_string_literal: true

module Admin
  module Navbar
    # The admin navbar: a few shortcut links beside a combobox of every admin page,
    # preceded by an "All" link back to the active page's index when this isn't it.
    # Picking an option navigates -- see admin/navbar_controller.js.
    class Component < ApplicationComponent
      def initialize(current_user:)
        @current_user = current_user
      end

      private

      # Shorter labels and a deliberate order, so these don't derive from nav_select_links
      def shortcut_links
        [["Users", admin_users_path],
          ["Bikes", admin_bikes_path],
          ["Organizations", admin_organizations_path],
          ["News", admin_news_index_path],
          ["Stolen", admin_stolen_bikes_path]]
      end

      # letter_opener_web_path only exists where the engine is mounted, so the guard
      # has to come first
      def mailer_links
        return [] unless Rails.env.development? || Rails.env.sandbox?

        [["Organized", "/rails/mailers/organized_mailer"],
          ["Admin", "/rails/mailers/admin_mailer"],
          ["Donation", "/rails/mailers/donation_mailer"],
          ["Customer", "/rails/mailers/customer_mailer"],
          ["Letter opener (view sent mail)", letter_opener_web_path]]
      end

      # Without an id the gem gives each option a uuid, which is most of the rendered
      # payload and barely compresses
      def combobox_options
        nav_select_links.each_with_index.map do |link, index|
          {display: link[:title], value: link[:path], id: "admin-nav-#{index}"}
        end
      end

      def placeholder
        active_link ? "Viewing #{active_link[:title]}" : "Admin navigation"
      end

      # Remove "Config:" and "Dev:" from the all link title
      def view_all_title
        active_link[:title].split(":").last
      end

      def display_view_all?
        return false unless active_link&.dig(:match_controller)

        !helpers.current_page_active?(active_link[:path]) || helpers.admin_search_filtered?
      end

      def active_link
        return @active_link if defined?(@active_link)

        @active_link = nav_select_links
          .detect { |link| helpers.current_page_active?(link[:path], link[:match_controller]) } || invoices_edit_link
      end

      # Because organization invoices edit doesn't match controller
      def invoices_edit_link
        return unless controller_name == "invoices" && action_name == "edit"

        nav_select_links.detect { |link| link[:title].match(/invoices/i) }
      end

      def nav_select_links
        @nav_select_links ||= ([
          {title: "Users", path: admin_users_path, match_controller: true},
          {title: "Bikes", path: admin_bikes_path, match_controller: true},
          {title: "Bike Versions", path: admin_bike_versions_path, match_controller: true},
          {title: "Stolen Bikes", path: admin_stolen_bikes_path, match_controller: true},
          {title: "Stolen Notifications", path: admin_stolen_notifications_url, match_controller: true},
          {title: "External Registry Bikes", path: admin_external_registry_bikes_path, match_controller: true},
          {title: "Config: External Registry Credentials", path: admin_external_registry_credentials_path, match_controller: true},
          {title: "Organizations", path: admin_organizations_path, match_controller: true},
          {title: "News", path: admin_news_index_path, match_controller: true},
          {title: "Content Tags", path: admin_content_tags_path, match_controller: true},
          {title: "POS Integration", path: lightspeed_interface_path, match_controller: false},
          {title: "Ambassador Activities", path: admin_ambassador_tasks_path, match_controller: true},
          {title: "Completed Ambassador Activities", path: admin_ambassador_task_assignments_path, match_controller: true},
          {title: "Promoted Alerts", path: admin_theft_alerts_path, match_controller: true},
          {title: "Promoted Alert Plans", path: admin_theft_alert_plans_path, match_controller: true},
          {title: "Memberships", path: admin_memberships_path, match_controller: true},
          {title: "Payments", path: admin_payments_path, match_controller: true},
          {title: "Organization Features", path: admin_organization_features_path, match_controller: true},
          {title: "Invoices", path: admin_invoices_path(query: "active", direction: "asc", sort: "subscription_end_at"), match_controller: true},
          {title: "Impound Records", path: admin_impound_records_path, match_controller: true},
          {title: "Parking Notifications", path: admin_parking_notifications_path, match_controller: true},
          {title: "Recoveries", path: admin_recoveries_path, match_controller: true},
          {title: "Recovery Displays", path: admin_recovery_displays_path, match_controller: true},
          {title: "Organization Roles", path: admin_organization_roles_path, match_controller: true},
          {title: "Manufacturers", path: admin_manufacturers_path, match_controller: true},
          {title: "Config: TSV Exports", path: admin_tsvs_path, match_controller: false},
          {title: "Credibility badges", path: admin_credibility_badges_path, match_controller: false},
          {title: "Maintenance", path: admin_maintenance_path, match_controller: false},
          {title: "Partial Bikes", path: admin_b_params_path, match_controller: true},
          {title: "Component Types", path: admin_ctypes_path, match_controller: true},
          {title: "Graphs", path: admin_graphs_path, match_controller: true},
          {title: "Paints", path: admin_paints_path, match_controller: true},
          {title: "Feedback & Messages", path: admin_feedbacks_path, match_controller: true},
          {title: "Bug Reports", path: admin_bug_reports_path, match_controller: true},
          {title: "Social Accounts", path: admin_social_accounts_path, match_controller: true},
          {title: "Social Posts", path: admin_social_posts_path, match_controller: true},
          {title: "Stickers", path: admin_bike_stickers_path, match_controller: true},
          {title: "Sticker Updates", path: admin_bike_sticker_updates_path, match_controller: true},
          {title: "Exports", path: admin_exports_path, match_controller: true},
          {title: "Bulk Imports", path: admin_bulk_imports_path, match_controller: true},
          {title: "Duplicate Bikes", path: duplicates_admin_bikes_path, match_controller: false},
          {title: "Model Audits", path: admin_model_audits_path, match_controller: true},
          {title: "Marketplace Listings", path: admin_marketplace_listings_path, match_controller: true},
          {title: "Marketplace Messages", path: admin_marketplace_messages_path, match_controller: true},
          {title: "Sales", path: admin_sales_path, match_controller: true},
          {title: "Logged bike searches", path: admin_logged_searches_path, match_controller: true},
          {title: "Organization statuses", path: admin_organization_statuses_path, match_controller: true},
          {title: "Config: Email Domains", path: admin_email_domains_path, match_controller: true},
          {title: "Config: Email Bans", path: admin_email_bans_path, match_controller: true},
          {title: "Config: Scheduled Jobs", path: admin_scheduled_jobs_path, match_controller: false},
          {title: "Config: Exchange Rates", path: admin_exchange_rates_path, match_controller: true},
          {title: "Config: Primary Activities", path: admin_primary_activities_path, match_controller: true},
          {title: "Bike Organization Notes", path: admin_bike_organization_notes_path, match_controller: true},
          {title: "Strava Integrations", path: admin_strava_integrations_path, match_controller: true},
          {title: "Exit Admin", path: root_path, match_controller: false}
        ] + dev_nav_select_links).sort_by { |link| link[:title] }
      end

      def dev_nav_select_links
        return [] unless @current_user.developer?

        [
          # Impound claims index is currently busted, so ignoring for now
          {title: "Dev: Impound Claims", path: admin_impound_claims_path, match_controller: true},
          {title: "Dev: Stripe Subscriptions", path: admin_stripe_subscriptions_path, match_controller: true},
          {title: "Dev: Stripe Prices", path: admin_stripe_prices_path, match_controller: true},
          {title: "Dev: Feature Flags", path: admin_feature_flags_path, match_controller: false},
          {title: "Dev: Mail Snippets", path: admin_mail_snippets_path, match_controller: true},
          {title: "Dev: Mailchimp Values", path: admin_mailchimp_values_path, match_controller: true},
          {title: "Dev: Mailchimp Data", path: admin_mailchimp_data_path, match_controller: true},
          {title: "Dev: User Alerts", path: admin_user_alerts_path, match_controller: true},
          {title: "Dev: Ownerships", path: admin_ownerships_path, match_controller: true},
          {title: "Dev: User Bans", path: admin_user_bans_path, match_controller: true},
          {title: "Dev: User Reg Organizations", path: admin_user_registration_organizations_path, match_controller: true},
          {title: "Dev: Autocomplete Status", path: admin_autocomplete_status_path, match_controller: false},
          {title: "Dev: OAuth Applications", path: oauth_applications_path(search_all: true), match_controller: true},
          {title: "Dev: Notifications", path: admin_notifications_path, match_controller: true},
          {title: "Dev: Superuser Abilities", path: admin_superuser_abilities_path, match_controller: true},
          {title: "Dev: Model Attestations", path: admin_model_attestations_path, match_controller: true},
          {title: "Dev: IP Location", path: admin_ip_location_path, match_controller: false},
          {title: "Dev: Strava Requests", path: admin_strava_requests_path, match_controller: true},
          {title: "Dev: Strava Activities", path: admin_strava_activities_path, match_controller: true},
          {title: "Dev: Strava Gear", path: admin_strava_gears_path, match_controller: true},
          {title: "Dev: Paper Trail Versions", path: admin_paper_trail_versions_path, match_controller: true},
          {title: "Dev: Registration Sequences", path: admin_registration_sequences_path, match_controller: true},
          {title: "Dev: Public Images", path: admin_public_images_path, match_controller: true}
        ]
      end
    end
  end
end
