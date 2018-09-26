class Admin::Organizations::InvoicesController < Admin::BaseController
  before_action :find_organization
  before_action :find_invoice, only: %i[edit update]
  before_action :find_paid_features, only: %i[new edit]

  def index
    @invoices = @organization.invoices.reorder(id: :desc)
  end

  def new
    @invoice ||= @organization.invoices.new
  end

  def show
    redirect_to edit_admin_organization_invoice_path
  end

  def edit; end

  def create
    @invoice = @organization.invoices.build(permitted_parameters.except(:paid_feature_ids))
    if @invoice.save
      # Invoice has to be created before it can get paid_feature_ids
      @invoice.paid_feature_ids = permitted_parameters[:paid_feature_ids]
      flash[:success] = "Invoice created"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :new
    end
  end

  def update
    if params[:create_following_invoice]
      if @invoice.create_following_invoice
        flash[:success] = "Invoice created"
      else
        flash[:error] = "unable to create following invoice. Was this invoice active?"
      end
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    elsif @invoice.update_attributes(permitted_parameters)
      flash[:success] = "Invoice created"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :edit
    end
  end

  protected

  def find_paid_features
    @paid_features = PaidFeature.order(:name)
  end

  def permitted_parameters
    params.require(:invoice).permit(:paid_feature_ids, :amount_due)
          .merge(subscription_start_at: TimeParser.parse(time_params[:subscription_start_at], time_params[:timezone]),
                 subscription_end_at: TimeParser.parse(time_params[:subscription_end_at], time_params[:timezone]))
  end

  def time_params
    params.require(:invoice).permit(:subscription_start_at, :subscription_end_at, :timezone)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:organization_id])
    return true if @organization.present?
    flash[:error] = "Sorry! That organization doesn't exist"
    redirect_to admin_organizations_url and return
  end

  def find_invoice
    @invoice = @organization.invoices.find(params[:id])
  end
end
