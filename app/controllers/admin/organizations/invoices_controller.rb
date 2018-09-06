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
    pp params
    redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
  end

  def update
  end

  protected

  def find_paid_features
    @paid_features = PaidFeature.order(:name)
  end

  def permitted_parameters
    params.require(:invoice)
          .permit(:paid_feature_ids, :subscription_start_at, :timezone, :amount_due)
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
