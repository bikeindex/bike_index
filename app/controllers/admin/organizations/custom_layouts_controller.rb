class Admin::Organizations::CustomLayoutsController < Admin::BaseController
  before_filter :define_edit_layout_pages
  before_filter :find_and_authorize_organization

  def index
  end

  def edit
    edit_template = @edit_layout_pages.include?(params[:id]) ? params[:id] : @edit_layout_pages.first
    render "edit_#{edit_template}"
  end

  def update
    # Needs to update approved before saving so set_locations_shown is applied on save
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = 'Organization Saved!'
      if params[:landing_page]
        redirect_to edit_admin_organization_url(@organization, landing_page: true)
      else
        redirect_to admin_organization_url(@organization)
      end
    else
      render action: :edit
    end
  end

  protected

  def permitted_parameters
    params.require(:organization).permit(permitted_organization_params)
  end

  def permitted_organization_params
    (%w(available_invitation_count sent_invitation_count name short_name slug website
       show_on_map is_suspended org_type embedable_user_email auto_user_id lock_show_on_map
       api_access_approved access_token new_bike_notification avatar avatar_cache
       lightspeed_cloud_api_key use_additional_registration_field approved landing_html
      ).map(&:to_sym) + [locations_attributes: permitted_locations_params]).freeze
  end

  def permitted_locations_params
    %w(name zipcode city state_id _destroy id country_id street phone email shown).map(&:to_sym)
  end

  def define_edit_layout_pages
    @edit_layout_pages ||= %w(landing mail_snippets)
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
