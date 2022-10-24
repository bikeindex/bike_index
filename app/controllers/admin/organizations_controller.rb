class Admin::OrganizationsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_organization, only: [:show, :edit, :update, :destroy]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @organizations = if sort_column == "bikes"
      matching_organizations.left_joins(:bikes).group(:id)
        .order("COUNT(bikes.id) #{sort_direction}")
    else
      matching_organizations
        .reorder("organizations.#{sort_column} #{sort_direction}")
    end.page(page).per(@per_page)
  end

  def show
    @locations = @organization.locations
    @deleted_memberships = @organization.deleted? || ParamsNormalizer.boolean(params[:deleted_memberships])
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

    # Also, special handling because we need to be able to unset manual_pos_kind
    manual_pos_kind = params.dig(:organization, :manual_pos_kind)
    if manual_pos_kind.present?
      if manual_pos_kind == "not_set"
        if @organization.manual_pos_kind.present?
          run_update_pos_kind = true
          @organization.manual_pos_kind = nil
        end
      elsif @organization.manual_pos_kind != manual_pos_kind
        run_update_pos_kind = true
        @organization.manual_pos_kind = manual_pos_kind
      end
    end
    if @organization.update(permitted_parameters)
      update_organization_stolen_message
      flash[:success] = "Organization Saved!"
      UpdateOrganizationPosKindWorker.perform_async(@organization.id) if run_update_pos_kind
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
      render action: :new
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
        :graduated_notification_interval_days,
        :lightspeed_register_with_phone,
        :lock_show_on_map,
        :manufacturer_id,
        :name,
        :direct_unclaimed_notifications,
        :parent_organization_id,
        :passwordless_user_domain,
        :previous_slug,
        :search_radius_miles,
        :search_radius_kilometers,
        :short_name,
        :show_on_map,
        :slug,
        :website,
        [locations_attributes: permitted_locations_params]
      ).merge(kind: approved_kind)
      .merge(registration_field_labels: registration_field_labels_val)
  end

  def matching_organizations
    return @matching_organizations if defined?(@matching_organizations)
    @search_paid = ParamsNormalizer.boolean(params[:search_paid])
    matching_organizations = Organization.unscoped.where(deleted_at: nil) # We don't want deleted orgs
    matching_organizations = matching_organizations.paid if @search_paid
    matching_organizations = matching_organizations.admin_text_search(params[:search_query]) if params[:search_query].present?
    @organization_features = OrganizationFeature.where(id: params[:search_organization_features])
    if @organization_features.any? # HACK - doesn't search InvoiceOrganizationFeature, just feature slugs
      matching_organizations = matching_organizations.with_enabled_feature_slugs(@organization_features.feature_slugs)
    end
    matching_organizations = matching_organizations.where(kind: params[:search_kind]) if params[:search_kind].present?
    matching_organizations = matching_organizations.where(pos_kind: pos_kind_for_organizations) if params[:search_pos].present?
    matching_organizations = matching_organizations.where(approved: (sort_direction == "desc")) if sort_column == "approved"
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    @matching_organizations = matching_organizations.where(@time_range_column => @time_range)
  end

  def sortable_columns
    %w[created_at name approved pos_kind bikes]
  end

  def pos_kind_for_organizations
    if params[:search_pos] == "with_pos"
      Organization.with_pos_kinds
    elsif params[:search_pos] == "without_pos"
      Organization.no_pos_kinds
    elsif params[:search_pos] == "broken_pos"
      Organization.broken_pos_kinds
    else
      params[:search_pos]
    end
  end

  def registration_field_labels_val
    # Get just the reg labels with values
    params.select { |k, v| k.match?("reg_label-") && v.present? }.as_json
      .map { |k, v| [k.gsub("reg_label-", ""), v.strip] }.to_h
  end

  def permitted_locations_params
    %i[name zipcode city state_id _destroy id country_id street phone email publicly_visible
      impound_location default_impound_location]
  end

  def update_organization_stolen_message
    message_params = {search_radius_miles: params[:organization_stolen_message_search_radius_miles],
                      kind: params[:organization_stolen_message_kind],
                      search_radius_kilometers: params[:organization_stolen_message_search_radius_kilometers]}
    return unless message_params.values.reject(&:blank?).any?
    OrganizationStolenMessage.for(@organization).update(message_params)
  end

  def find_organization
    @organization = Organization.unscoped.friendly_find(params[:id])
    return true if @organization.present?
    raise ActiveRecord::RecordNotFound # Because this should have been raised
  end
end
