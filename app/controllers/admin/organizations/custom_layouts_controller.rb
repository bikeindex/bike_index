module Admin
  module Organizations
    class CustomLayoutsController < Admin::BaseController
      before_action :find_and_authorize_organization

      BUTTON_COLOR_MATCHER = /button=#?(\h{3}|\h{6})\b/
      BUTTON_HOVER_MATCHER = /button_hover=/

      def index
      end

      def edit
        @edit_template = edit_layout_pages.include?(params[:id]) ? params[:id] : edit_layout_pages.first
        if @edit_template != "landing_page" # we're rendering a snippet
          @mail_snippet = @organization.mail_snippets.where(kind: @edit_template).first_or_create
        end
      end

      def update
        if @organization.update(permitted_parameters)
          flash[:success] = "Layout Saved!"
          redirect_to edit_admin_organization_custom_layout_path(organization_id: @organization.to_param, id: params[:id])
        else
          render action: :edit, id: params[:id]
        end
      end

      helper_method :layout_kind, :suggested_button_hover

      protected

      # Step 1 derives a hover shade from the button color, but a page that names its own
      # keeps the pair somewhere the person editing the markup can see them
      def suggested_button_hover
        landing_html = @organization.landing_html
        return if landing_html.blank? || landing_html.match?(BUTTON_HOVER_MATCHER)

        HexColor.darken_hex(landing_html[BUTTON_COLOR_MATCHER, 1])
      end

      def permitted_parameters
        params.require(:organization)
          .permit(:landing_html, mail_snippets_attributes: [:body, :is_enabled, :id])
      end

      def edit_layout_pages
        @edit_layout_pages ||= MailSnippet.organization_snippet_kinds + %w[landing_page]
      end

      def layout_kind
        return "landing_page" if params[:id] == "landing_page"

        "mail_snippet"
      end

      def find_and_authorize_organization
        @organization = Organization.friendly_find(params[:organization_id])
        unless current_user.developer?
          flash[:notice] = "Sorry, you must be a developer to access that page."
          redirect_to(admin_organization_url(@organization)) && return
        end
        unless @organization
          flash[:error] = "Sorry! That organization doesn't exist"
          redirect_to(admin_organizations_url) && return
        end
      end
    end
  end
end
