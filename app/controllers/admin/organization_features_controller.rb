class Admin::OrganizationFeaturesController < Admin::BaseController
  include SortableTable
  before_action :find_organization_feature, only: %i[edit update]

  def index
    @organization_features = OrganizationFeature.order(sort_column + " " + sort_direction)
  end

  def new
    @organization_feature ||= OrganizationFeature.new
  end

  def show
    redirect_to edit_admin_organization_feature_path
  end

  def edit
    @invoices = @organization_feature.invoices.includes(:organization, :payments)
  end

  def update
    @organization_feature.update_attributes(permitted_update_parameters)
    flash[:success] = "Feature updated" unless flash[:error].present?
    redirect_to admin_organization_features_path
  end

  def create
    @organization_feature = OrganizationFeature.new(permitted_update_parameters)
    if @organization_feature.save
      flash[:success] = "Feature created"
      redirect_to admin_organization_features_path
    else
      flash[:error] = "Unable to create"
      render :new
    end
  end

  protected

  def sortable_columns
    %w[name created_at kind amount_cents]
  end

  # Because we start with alpha ordering
  def default_direction
    "asc"
  end

  def permitted_update_parameters
    permitted_parameters = params.require(:organization_feature).permit(:amount, :description, :details_link, :kind, :name, :currency)
    if current_user.developer?
      permitted_parameters.merge(params.require(:organization_feature).permit(:feature_slugs_string))
    elsif @organization_feature&.id&.present? && @organization_feature.locked?
      flash[:error] = "Can't update locked organization feature! Please ask Seth"
      {}
    else
      permitted_parameters
    end
  end

  def find_organization_feature
    @organization_feature = OrganizationFeature.find(params[:id])
  end
end
