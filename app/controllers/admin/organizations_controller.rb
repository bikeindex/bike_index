class Admin::OrganizationsController < Admin::BaseController
  include SortableTable
  before_filter :find_organization, only: [:show, :edit, :update, :destroy]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @organizations = matching_organizations.reorder("organizations.#{sort_column} #{sort_direction}").page(page).per(per_page)
  end

  def show
    @locations = @organization.locations
    @bikes = @organization.bikes.reorder("created_at desc").page(1).per(10)
  end

  def show_deleted
    @organizations = Organization.only_deleted.all
  end

  def recover
    @organization = Organization.only_deleted.find(params[:id]).restore(recursive: true)
    redirect_to admin_organizations_url
  end

  def new
    @organization = Organization.new
  end

  def edit
    @embedable_email = @organization.auto_user.email if @organization.auto_user
  end

  def update
    # Needs to update approved before saving so set_locations_shown is applied on save
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = "Organization Saved!"
      redirect_to admin_organization_url(@organization)
    else
      render action: :edit
    end
  end

  def create
    @organization = Organization.new(permitted_parameters)
    @organization.approved = true
    if @organization.save
      flash[:success] = "Organization Created!"
      redirect_to edit_admin_organization_url(@organization)
    else
      render action: :create
    end
  end

  def destroy
    @organization.destroy
    redirect_to admin_organizations_url
  end

  helper_method :matching_organizations

  protected

  def permitted_parameters
    approved_kind = params.dig(:organization, :kind)
    approved_kind = "other" unless Organization.kinds.include?(approved_kind)
    params
      .require(:organization)
      .permit(
        :access_token,
        :api_access_approved,
        :approved,
        :ascend_name,
        :auto_user_id,
        :available_invitation_count,
        :avatar,
        :avatar_cache,
        :embedable_user_email,
        :is_suspended,
        :lightspeed_cloud_api_key,
        :lock_show_on_map,
        :name,
        :parent_organization_id,
        :previous_slug,
        :search_radius,
        :short_name,
        :show_on_map,
        :slug,
        :website,
        [locations_attributes: permitted_locations_params],
      ).merge(kind: approved_kind)
  end

  def matching_organizations
    return @matching_organizations if defined?(@matching_organizations)
    @search_paid = ParamsNormalizer.boolean(params[:search_paid])
    matching_organizations = Organization.unscoped
    matching_organizations = matching_organizations.paid if @search_paid
    matching_organizations = matching_organizations.admin_text_search(params[:search_query]) if params[:search_query].present?
    matching_organizations = matching_organizations.where(kind: kind_for_organizations) if params[:search_kind].present?
    matching_organizations = matching_organizations.where(pos_kind: pos_kind_for_organizations) if params[:search_pos].present?
    @matching_organizations = matching_organizations
  end

  def sortable_columns
    %w[created_at name approved pos_kind]
  end

  def kind_for_organizations
    # Legacy enum issue so excited for TODO: Rails 5 update
    Organization::KIND_ENUM[params[:search_kind].to_sym] || 0
  end

  def pos_kind_for_organizations
    if params[:search_pos] == "no_pos"
      # We want to return both no_pos and does_not_need_pos
      return [Organization::POS_KIND_ENUM[:no_pos], Organization::POS_KIND_ENUM[:does_not_need_pos]]
    end
    # Legacy enum issue so excited for TODO: Rails 5 update
    Organization::POS_KIND_ENUM[params[:search_pos].to_sym] || 0
  end

  def permitted_locations_params
    %w(name zipcode city state_id _destroy id country_id street phone email shown).map(&:to_sym)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:id])
    return true if @organization.present?
    raise ActiveRecord::RecordNotFound # Because by all rights, this should have been raised
  rescue ActiveRecord::RecordNotFound
    @organization = Organization.unscoped.friendly_find(params[:id])
    if @organization.present?
      flash[:error] = "This organization is deleted! Things might not work correctly in here"
      return true
    else
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end
end
