# frozen_string_literal: true

module Admin
  module CustomLayouts
    module Form
      module MailSnippet
        # Editing one of an organization's mail snippets, with the images it can reference.
        class Component < ApplicationComponent
          def initialize(organization:, mail_snippet:, edit_template:)
            @organization = organization
            @mail_snippet = mail_snippet
            @edit_template = edit_template
          end

          private

          def form_url
            admin_organization_custom_layout_path(organization_id: @organization.to_param, id: @edit_template)
          end

          def enable_label
            safe_join(["Enable", tag.strong(@edit_template.titleize), "snippet",
              tag.em("only possible if there is content")], " ")
          end

          def description_for(kind)
            ::MailSnippet.organization_snippets.dig(kind.to_sym, :description)
          end
        end
      end
    end
  end
end
