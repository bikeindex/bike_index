class Admin::PaidFeaturesController < Admin::BaseController
  include SortableTable
  before_filter :find_paid_feature, only: [:edit, :update]

  def index
    @paid_features = PaidFeature.order(sort_column + " " + sort_direction)
  end

  def new
    @paid_feature ||= PaidFeature.new
  end

  def show
    redirect_to edit_admin_paid_feature_path
  end

  def edit; end

  def update
    @paid_feature.update_attributes(permitted_update_parameters)
    flash[:success] = "Feature updated"
    redirect_to admin_paid_features_path
  end

  def create
    @paid_feature = PaidFeature.new(permitted_parameters)
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
    %w(created_at kind name amount_cents)
  end

  def permitted_update_parameters
    if @paid_feature.locked?
      permitted_parameters.except("kind", "name")
    else
      permitted_parameters
    end
  end

  def permitted_parameters
    params.require(:paid_feature).permit(:amount, :description, :details_link, :kind, :name)
  end

  def find_paid_feature
    @paid_feature = PaidFeature.friendly_find(params[:id])
  end
end
