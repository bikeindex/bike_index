# frozen_string_literal: true

module Admin
  module CustomLayoutForm
    module Wrapper
      # The custom layouts tab for one template. Which form renders, the subtitle and the
      # top-right link all turn on whether the template is the landing page, so the header
      # renders here rather than leaving the view to answer that three times.
      class Component < ApplicationComponent
        LANDING_PAGE = "landing_page"
        LINK_CLASSES = "nav-link btn btn-sm btn-outline-info"

        def initialize(organization:, edit_template:, landing_page: nil, mail_snippet: nil,
          landing_page_url: nil, suggested_button_hover: nil)
          @organization = organization
          @edit_template = edit_template
          @landing_page = landing_page
          @mail_snippet = mail_snippet
          @landing_page_url = landing_page_url
          @suggested_button_hover = suggested_button_hover
        end

        private

        def landing_page? = @edit_template == LANDING_PAGE

        def subtitle
          return "Landing Page" if landing_page?

          safe_join([tag.strong(@edit_template.titleize), "email snippet"], " ")
        end

        def additional_link
          return link_to("landing page", @landing_page_url, class: LINK_CLASSES) if landing_page?

          snippet_kind = @mail_snippet.which_organization_email
          link_to("#{snippet_kind.titleize} email",
            edit_organization_email_path(snippet_kind, organization_id: @organization.to_param),
            class: LINK_CLASSES)
        end

        def layout_form
          if landing_page?
            Admin::CustomLayoutForm::LandingPage::Component.new(organization: @organization,
              landing_page: @landing_page, suggested_button_hover: @suggested_button_hover)
          else
            Admin::CustomLayoutForm::MailSnippet::Component.new(organization: @organization,
              mail_snippet: @mail_snippet, edit_template: @edit_template)
          end
        end
      end
    end
  end
end
