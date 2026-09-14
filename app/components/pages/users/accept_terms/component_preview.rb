# frozen_string_literal: true

module Pages
  module Users
    module AcceptTerms
      class ComponentPreview < ApplicationComponentPreview
        def default
          preview_for(:terms_of_service, "users.accept_terms")
        end

        def vendor_terms
          preview_for(:vendor_terms_of_service, "users.accept_vendor_terms")
        end

        private

        def preview_for(attribute, scope)
          render(Pages::Users::AcceptTerms::Component.new(user: lookbook_user, attribute:,
            label: ActiveSupport::HtmlSafeTranslation.translate("#{scope}.i_agree_to_tos_html"),
            submit_text: I18n.t("#{scope}.submit")))
        end
      end
    end
  end
end
