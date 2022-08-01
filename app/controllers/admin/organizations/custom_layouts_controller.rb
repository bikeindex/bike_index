class Admin::Organizations::CustomLayoutsController < Admin::BaseController
  before_action :find_and_authorize_organization

  def index
  end

  def edit
    @edit_template = edit_layout_pages.include?(params[:id]) ? params[:id] : edit_layout_pages.first
    if @edit_template == "organization_stolen_message"
      @organization_stolen_message = OrganizationStolenMessage.for(@organization)
    elsif @edit_template != "landing_page" # we're rendering a snippet
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

  helper_method :layout_kind

  protected

  def permitted_parameters
    params.require(:organization)
      .permit(:landing_html, mail_snippets_attributes: [:body, :is_enabled, :id],
        organization_stolen_message_attributes: [:body, :is_enabled, :id])
  end

  def edit_layout_pages
    @edit_layout_pages ||= MailSnippet.organization_snippet_kinds +
      %w[landing_page organization_stolen_message]
  end

  def layout_kind
    return "landing_page" if params[:id] == "landing_page"
    return "organization_stolen_message" if params[:id] == "organization_stolen_message"
    "mail_snippet"
  end

  def find_and_authorize_organization
    @organization = Organization.friendly_find(params[:organization_id])
    unless current_user.developer?
      flash[:info] = "Sorry, you must be a developer to access that page."
      redirect_to(admin_organization_url(@organization)) && return
    end
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to(admin_organizations_url) && return
    end
  end
end
