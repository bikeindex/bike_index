class Admin::PaidFeaturesController < Admin::BaseController
  include SortableTable
  before_filter :find_paid_feature, only: %i[edit update]
  layout "new_admin"

  def index
    @paid_features = PaidFeature.order(sort_column + " " + sort_direction)
  end

  def new
    @paid_feature ||= PaidFeature.new
  end

  def show
    redirect_to edit_admin_paid_feature_path
  end

  def edit
    @invoices = @paid_feature.invoices.includes(:organization, :payments)
  end

  def update
    @paid_feature.update_attributes(permitted_update_parameters)
    flash[:success] = "Feature updated" unless flash[:error].present?
    redirect_to admin_paid_features_path
  end

  def create
    @paid_feature = PaidFeature.new(permitted_update_parameters)
    if @paid_feature.save
      flash[:success] = "Feature created"
      redirect_to admin_paid_features_path
    else
      flash[:error] = "Unable to create"
      render :new
    end
  end

  protected

  def sortable_columns
    %w[created_at kind name amount_cents]
  end

  def permitted_update_parameters
    permitted_parameters = params.require(:paid_feature).permit(:amount, :description, :details_link, :kind, :name)
    if current_user.developer?
      permitted_parameters.merge(params.require(:paid_feature).permit(:feature_slugs_string))
    elsif @paid_feature&.id&.present? && @paid_feature.locked?
      flash[:error] = "Can't update locked paid feature! Please ask Seth"
      {}
    else
      permitted_parameters
    end
  end

  def find_paid_feature
    @paid_feature = PaidFeature.find(params[:id])
  end
end
