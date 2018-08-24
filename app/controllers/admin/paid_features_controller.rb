class Admin::PaidFeaturesController < Admin::BaseController
  before_filter :find_paid_feature, only: [:edit, :update]

  def index
    @paid_features = PaidFeature.order(created_at: :desc)
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
    flash[:success] = "Feature created"
    redirect_to admin_paid_features_path
  end

  def create
    @paid_feature = PaidFeature.new(permitted_parameters)
    if @paid_feature.save
      flash[:success] = "Feature created"
      redirect_to admin_paid_features_path
    else
      flash[:error] = "unable to create"
      render :new
    end
  end

  protected

  def permitted_update_parameters
    if @paid_feature.locked?
      permitted_parameters.except("kind", "name")
    else
      permitted_parameters
    end
  end

  def permitted_parameters
    params.require(:paid_feature).permit(:amount_cents, :description, :details_link, :kind, :name)
  end

  def find_paid_feature
    @paid_feature = PaidFeature.friendly_find(params[:id])
  end
end
