class Admin::Organizations::CustomLayoutsController < Admin::BaseController
  before_filter :find_and_authorize_organization

  def index
  end

  def edit
    @edit_template = edit_layout_pages.include?(params[:id]) ? params[:id] : edit_layout_pages.first
    render "edit_#{@edit_template}"
  end

  def update
    # Needs to update approved before saving so set_locations_shown is applied on save
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = 'Organization Saved!'
      redirect_to edit_admin_organization_custom_layout_path(organization_id: @organization.to_param, id: params[:id])
    else
      render action: :edit
    end
  end

  protected

  def permitted_parameters
    params.require(:organization).permit(:landing_html)
  end

  def edit_layout_pages
    @edit_layout_pages ||= %w(landing_page mail_snippets)
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
