class Admin::Organizations::InvoicesController < Admin::BaseController
  before_action :find_organization
  before_action :find_invoice, only: %i[edit update]
  before_action :find_paid_features, only: %i[new edit]

  def index
    @invoices = @organization.invoices.order(id: :desc)
  end

  def new
    @invoice = @organization.invoices.new
  end

  def show
    redirect_to edit_admin_organization_invoice_path
  end

  def edit; end

  def create
  end

  def update
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = 'Organization Saved!'
      redirect_to edit_admin_organization_custom_layout_path(organization_id: @organization.to_param, id: params[:id])
    else
      render action: :edit, id: params[:id]
    end
  end

  protected

  def find_paid_features
    @paid_features = PaidFeature.order(:name)
  end

  def permitted_parameters
    params.require(:invoice)
          .permit(:paid_feature_ids, :subscription_start_at, :amount_due)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:organization_id])
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end

  def find_invoice
    @invoice = @organization.invoices.find(params[:id])
  end
end
