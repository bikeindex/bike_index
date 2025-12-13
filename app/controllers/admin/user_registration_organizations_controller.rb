class Admin::UserRegistrationOrganizationsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @user_registration_organizations = pagy(matching_user_registration_organizations
      .reorder("user_registration_organizations.#{sort_column} #{sort_direction}")
      .includes(:user, :organization), limit: @per_page, page: permitted_page)
    @render_org_counts = Binxtils::InputNormalizer.boolean(params[:search_org_counts])
  end

  helper_method :matching_user_registration_organizations

  private

  def sortable_columns
    %w[created_at updated_at user_id organization_id]
  end

  def earliest_period_date
    Time.at(1641448800)
  end

  def matching_user_registration_organizations
    user_registration_organizations = UserRegistrationOrganization
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      user_registration_organizations = user_registration_organizations.where(user_id: @user.id)
    end
    if current_organization.present?
      user_registration_organizations = user_registration_organizations.where(organization_id: current_organization.id)
    end
    @with_registration_info = Binxtils::InputNormalizer.boolean(params[:search_with_registration_info])
    if @with_registration_info
      user_registration_organizations = user_registration_organizations.where.not(registration_info: {})
    end
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    user_registration_organizations.where(@time_range_column => @time_range)
  end
end
