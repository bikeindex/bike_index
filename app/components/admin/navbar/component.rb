# frozen_string_literal: true

module Admin
  module Navbar
    # The admin navbar: a few shortcut links beside a combobox of every admin page,
    # preceded by an "All" link back to the active page's index when this isn't it.
    # Picking an option navigates -- see admin/navbar_controller.js.
    class Component < ApplicationComponent
      # The vendored dump's .navbar-light .navbar-nav .nav-link, as utilities. admin.scss
      # imports the dump unlayered, so it outranks every tailwind layer — dropping .nav-link
      # is what lets a utility reach these links at all. Horizontal padding is the
      # navbar-expand-md value, the only one the d-lg-flex list is ever visible at.
      NAV_LINK_CLASS = "tw:block tw:p-2 tw:no-underline tw:text-black/50 " \
        "tw:hover:text-black/70 tw:focus:text-black/70 tw:is-active:text-black/90"

      def initialize(current_user:, user_root_url:, search_filtered: false)
        @current_user = current_user
        @user_root_url = user_root_url
        @search_filtered = search_filtered
      end

      private

      # Shorter labels and a deliberate order, so the titles don't derive from nav_select_links.
      # What each covers does, so a shortcut and the picker agree on how wide the current page is.
      def shortcut_links
        {"Users" => admin_users_path,
         "Bikes" => admin_bikes_path,
         "Organizations" => admin_organizations_path,
         "News" => admin_news_index_path,
         "Stolen" => admin_stolen_bikes_path}
          .map { |title, path| {title:, path:, match_paths: match_paths_for(nav_link_for(path))} }
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
        current_nav_link ? "Viewing #{current_nav_link[:title]}" : "Admin navigation"
      end

      # Remove "Config:" and "Dev:" from the all link title
      def view_all_title
        current_nav_link[:title].split(":").last
      end

      def display_view_all?
        return false unless current_link_has_sub_pages?

        @search_filtered ||
          request.path != UI::ActiveLink::Component.page_path(current_nav_link[:path])
      end

      # Only a section-wide link goes active on pages other than its own, so it's the only
      # kind with anywhere to offer a way back from
      def current_link_has_sub_pages?
        current_nav_link.present? && !current_nav_link[:exact]
      end

      # The narrowest entry covering the page, so an organization's invoices are the invoices
      # index's rather than the organizations section they're nested under
      def current_nav_link
        return @current_nav_link if defined?(@current_nav_link)

        covering = nav_select_links.filter_map do |link|
          pattern = covering_pattern(link)
          [link, pattern.count("/")] if pattern
        end
        @current_nav_link = covering.max_by { |_link, depth| depth }&.first
      end

      # The picker names the current page in prose, which UI::ActiveLink can't answer for it —
      # bar the five shortcuts, the entries are picker options rather than links
      def covering_pattern(link)
        Array.wrap(match_paths_for(link))
          .detect { |pattern| UI::ActiveLink::Component.covers?(pattern, request.path) }
      end

      def nav_link_for(path)
        nav_select_links.detect { |link| link[:path] == path }
      end

      # An exact: entry is one action on a controller another entry owns -- most of
      # admin/dashboard's pages, duplicates on admin/bikes -- which would otherwise send
      # every entry on that controller active at once. An entry's path is what the picker
      # navigates to, so it carries the query a page needs and, once, an origin — no part
      # of the page it names.
      def match_paths_for(link)
        return link[:match_paths] if link[:match_paths]

        path = UI::ActiveLink::Component.page_path(link[:path])
        link[:exact] ? path : "#{path}/**"
      end

      def nav_select_links
        @nav_select_links ||= ([
          {title: "Users", path: admin_users_path},
          {title: "Bikes", path: admin_bikes_path},
          {title: "Bike Versions", path: admin_bike_versions_path},
          {title: "Stolen Bikes", path: admin_stolen_bikes_path},
          {title: "Stolen Notifications", path: admin_stolen_notifications_url},
          {title: "External Registry Bikes", path: admin_external_registry_bikes_path},
          {title: "Config: External Registry Credentials", path: admin_external_registry_credentials_path},
          # organizations#recover is routed outside the section's own path
          {title: "Organizations", path: admin_organizations_path,
           match_paths: ["#{admin_organizations_path}/**", admin_recover_organization_path]},
          {title: "News", path: admin_news_index_path},
          {title: "Content Tags", path: admin_content_tags_path},
          {title: "POS Integration", path: lightspeed_interface_path, exact: true},
          {title: "Ambassador Activities", path: admin_ambassador_tasks_path},
          {title: "Completed Ambassador Activities", path: admin_ambassador_task_assignments_path},
          {title: "Promoted Alerts", path: admin_theft_alerts_path},
          {title: "Promoted Alert Plans", path: admin_theft_alert_plans_path},
          {title: "Memberships", path: admin_memberships_path},
          {title: "Payments", path: admin_payments_path},
          {title: "Organization Features", path: admin_organization_features_path},
          {title: "Registration Sequences", path: admin_registration_sequences_path},
          # An organization's invoices are the same section, on a path nested under theirs
          {title: "Invoices", path: admin_invoices_path(query: "active", direction: "asc", sort: "subscription_end_at"),
           match_paths: ["#{admin_invoices_path}/**", "#{admin_organizations_path}/*/invoices"]},
          {title: "Impound Records", path: admin_impound_records_path},
          {title: "Parking Notifications", path: admin_parking_notifications_path},
          {title: "Recoveries", path: admin_recoveries_path},
          {title: "Recovery Displays", path: admin_recovery_displays_path},
          {title: "Organization Roles", path: admin_organization_roles_path},
          {title: "Manufacturers", path: admin_manufacturers_path},
          {title: "Config: TSV Exports", path: admin_tsvs_path, exact: true},
          {title: "Credibility badges", path: admin_credibility_badges_path, exact: true},
          {title: "Maintenance", path: admin_maintenance_path, exact: true},
          {title: "Partial Bikes", path: admin_b_params_path},
          {title: "Component Types", path: admin_ctypes_path},
          {title: "Graphs", path: admin_graphs_path},
          {title: "Paints", path: admin_paints_path},
          {title: "Feedback & Messages", path: admin_feedbacks_path},
          {title: "Bug Reports", path: admin_bug_reports_path},
          {title: "Social Accounts", path: admin_social_accounts_path},
          {title: "Social Posts", path: admin_social_posts_path},
          {title: "Stickers", path: admin_bike_stickers_path},
          {title: "Sticker Updates", path: admin_bike_sticker_updates_path},
          {title: "Exports", path: admin_exports_path},
          {title: "Bulk Imports", path: admin_bulk_imports_path},
          {title: "Duplicate Bikes", path: duplicates_admin_bikes_path, exact: true},
          {title: "Model Audits", path: admin_model_audits_path},
          {title: "Marketplace Listings", path: admin_marketplace_listings_path},
          {title: "Marketplace Messages", path: admin_marketplace_messages_path},
          {title: "Sales", path: admin_sales_path},
          {title: "Logged bike searches", path: admin_logged_searches_path},
          {title: "Organization statuses", path: admin_organization_statuses_path},
          {title: "Config: Email Domains", path: admin_email_domains_path},
          {title: "Config: Email Bans", path: admin_email_bans_path},
          {title: "Config: Scheduled Jobs", path: admin_scheduled_jobs_path, exact: true},
          {title: "Config: Exchange Rates", path: admin_exchange_rates_path},
          {title: "Config: Primary Activities", path: admin_primary_activities_path},
          {title: "Bike Organization Notes", path: admin_bike_organization_notes_path},
          {title: "Strava Integrations", path: admin_strava_integrations_path},
          {title: "Exit Admin", path: root_path, exact: true}
        ] + dev_nav_select_links).sort_by { |link| link[:title] }
      end

      def dev_nav_select_links
        return [] unless @current_user.developer?

        [
          # Impound claims index is currently busted, so ignoring for now
          {title: "Dev: Impound Claims", path: admin_impound_claims_path},
          {title: "Dev: Stripe Subscriptions", path: admin_stripe_subscriptions_path},
          {title: "Dev: Stripe Prices", path: admin_stripe_prices_path},
          {title: "Dev: Feature Flags", path: admin_feature_flags_path, exact: true},
          {title: "Dev: Mail Snippets", path: admin_mail_snippets_path},
          {title: "Dev: Mailchimp Values", path: admin_mailchimp_values_path},
          {title: "Dev: Mailchimp Data", path: admin_mailchimp_data_path},
          {title: "Dev: User Alerts", path: admin_user_alerts_path},
          {title: "Dev: Ownerships", path: admin_ownerships_path},
          {title: "Dev: User Bans", path: admin_user_bans_path},
          {title: "Dev: User Reg Organizations", path: admin_user_registration_organizations_path},
          {title: "Dev: Autocomplete Status", path: admin_autocomplete_status_path, exact: true},
          {title: "Dev: OAuth Applications", path: oauth_applications_path(search_all: true)},
          {title: "Dev: Notifications", path: admin_notifications_path},
          {title: "Dev: Organization Landing Pages", path: admin_organization_landing_pages_path},
          {title: "Dev: Superuser Abilities", path: admin_superuser_abilities_path},
          {title: "Dev: Model Attestations", path: admin_model_attestations_path},
          {title: "Dev: IP Location", path: admin_ip_location_path, exact: true},
          {title: "Dev: Strava Requests", path: admin_strava_requests_path},
          {title: "Dev: Strava Activities", path: admin_strava_activities_path},
          {title: "Dev: Strava Gear", path: admin_strava_gears_path},
          {title: "Dev: Paper Trail Versions", path: admin_paper_trail_versions_path},
          {title: "Dev: Public Images", path: admin_public_images_path}
        ]
      end
    end
  end
end
