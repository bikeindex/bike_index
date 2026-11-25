# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module CustomLayouts
        module Form
          module Wrapper
            # The custom layouts tab for one template. Everything that turns on whether the template
            # is the landing page - which form renders, the subtitle, the top-right link, the record
            # the history link points at - resolves here rather than in the view.
            class Component < ApplicationComponent
              LANDING_PAGE = "landing_page"

              def initialize(organization:, edit_template:, landing_page: nil, mail_snippet: nil,
                landing_page_url: nil, suggested_button_hover: nil, display_dev_info: false)
                @organization = organization
                @display_dev_info = display_dev_info
                @edit_template = edit_template
                @landing_page = landing_page
                @mail_snippet = mail_snippet
                @landing_page_url = landing_page_url
                @suggested_button_hover = suggested_button_hover
              end

              private

              def landing_page? = @edit_template == LANDING_PAGE

              def edited_record = landing_page? ? @landing_page : @mail_snippet

              # A landing page is built rather than created, so it has no history until it saves
              def version_history_path
                return unless edited_record.persisted?

                admin_paper_trail_versions_path(search_item_type: edited_record.class.name,
                  search_item_id: edited_record.id, period: "all")
              end

              def version_history_link
                return if version_history_path.blank?

                render(UI::Container::Component.new(width: :wide)) do
                  tag.div(link_to("View history of this #{landing_page? ? "landing page" : "snippet"}",
                    version_history_path, class: "twlink"), class: "tw:mb-8")
                end
              end

              def subtitle
                return "Landing Page" if landing_page?

                safe_join([tag.strong(@edit_template.titleize), "email snippet"], " ")
              end

              def additional_link
                return tab_link("landing page", @landing_page_url) if landing_page?

                snippet_kind = @mail_snippet.which_organization_email
                tab_link("#{snippet_kind.titleize} email",
                  edit_organization_email_path(snippet_kind, organization_id: @organization.to_param))
              end

              def tab_link(text, href)
                render(UI::ButtonLink::Component.new(text:, href:, size: :sm))
              end

              def layout_form
                if landing_page?
                  Pages::Admin::Organizations::CustomLayouts::Form::LandingPage::Component.new(organization: @organization,
                    landing_page: @landing_page, suggested_button_hover: @suggested_button_hover)
                else
                  Pages::Admin::Organizations::CustomLayouts::Form::MailSnippet::Component.new(organization: @organization,
                    mail_snippet: @mail_snippet, edit_template: @edit_template)
                end
              end
            end
          end
        end
      end
    end
  end
end
