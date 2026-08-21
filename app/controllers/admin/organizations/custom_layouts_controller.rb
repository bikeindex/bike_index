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
        if landing_page?
          @landing_page = edited_record
        else
          @mail_snippet = @organization.mail_snippets.where(kind: @edit_template).first_or_create
        end
      end

      def update
        if edited_record.update(permitted_parameters)
          flash[:success] = "Layout Saved!"
          redirect_to edit_admin_organization_custom_layout_path(organization_id: @organization.to_param, id: params[:id])
        else
          render action: :edit, id: params[:id]
        end
      end

      helper_method :layout_kind, :suggested_button_hover, :landing_page_url

      protected

      # Built, not created - only a save should create the page
      def edited_record
        return @organization unless landing_page?

        @landing_page ||= @organization.organization_landing_page || @organization.build_organization_landing_page
      end

      # Only routed at boot from LandingPages::ORGANIZATIONS; outside it, the members' preview is all there is.
      # Nil-safe because the view passes it for a mail snippet too, which has no landing page
      def landing_page_url
        return "#{root_url}#{@organization.to_param}" if @landing_page&.env_enabled?

        organization_landing_url(organization_id: @organization.to_param)
      end

      # Step 1 derives a hover shade from the button color, but a page that names its own
      # keeps the pair somewhere the person editing the markup can see them
      def suggested_button_hover
        body = @landing_page&.body
        return if body.blank? || body.match?(BUTTON_HOVER_MATCHER)

        HexColor.darken_hex(body[BUTTON_COLOR_MATCHER, 1])
      end

      def permitted_parameters
        return params.require(:organization_landing_page).permit(:body, :enabled) if landing_page?

        params.require(:organization).permit(mail_snippets_attributes: [:body, :is_enabled, :id])
      end

      def edit_layout_pages
        @edit_layout_pages ||= MailSnippet.organization_snippet_kinds + %w[landing_page]
      end

      def landing_page?
        params[:id] == "landing_page"
      end

      def layout_kind
        landing_page? ? "landing_page" : "mail_snippet"
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
