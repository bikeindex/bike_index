class Admin::Organizations::CustomLayoutsController < Admin::BaseController
  before_filter :find_and_authorize_organization

  def index
  end

  def edit
    @edit_template = edit_layout_pages.include?(params[:id]) ? params[:id] : edit_layout_pages.first
    unless @edit_template == 'landing_page' # Otherwise, we're rendering a snippet
      @mail_snippet = @organization.mail_snippets.where(name: @edit_template).first_or_create
    end
  end

  def update
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = 'Organization Saved!'
      redirect_to edit_admin_organization_custom_layout_path(organization_id: @organization.to_param, id: params[:id])
    else
      render action: :edit, id: params[:id]
    end
  end

  protected

  def permitted_parameters
    params.require(:organization)
          .permit(:landing_html, mail_snippets_attributes: [:body, :is_enabled, :id])
  end

  def edit_layout_pages
    @edit_layout_pages ||= MailSnippet.organization_snippet_types + %w(landing_page)
  end

  def find_and_authorize_organization
    @organization = Organization.friendly_find(params[:organization_id])
    unless current_user.developer
      flash[:info] = 'Sorry, you must be a developer to access that page.'
      redirect_to admin_organization_url(@organization) and return
    end
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end
end
