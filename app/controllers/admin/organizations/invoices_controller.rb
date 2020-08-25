class Admin::Organizations::InvoicesController < Admin::BaseController
  before_action :find_organization
  before_action :find_invoice, only: %i[edit update]
  before_action :find_organization_features, only: %i[new edit]

  def index
    @invoices = @organization.invoices.reorder(id: :desc)
  end

  def new
    @invoice ||= @organization.invoices.new
    @invoice.end_at = TimeParser.parse(params[:end_at]) if params[:end_at].present?
  end

  def show
    redirect_to edit_admin_organization_invoice_path
  end

  def edit
  end

  def create
    @invoice = @organization.invoices.build(permitted_parameters.except(:organization_feature_ids, :child_enabled_feature_slugs))
    if @invoice.save
      # Invoice has to be created before it can get organization_feature_ids
      @invoice.organization_feature_ids = permitted_parameters[:organization_feature_ids]
      @invoice.update_attributes(child_enabled_feature_slugs_string: permitted_parameters[:child_enabled_feature_slugs_string])
      flash[:success] = "Invoice created! #{invoice_is_active_notice(@invoice)}"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :new
    end
  end

  def update
    if params[:create_following_invoice]
      if @invoice.create_following_invoice
        flash[:success] = "Invoice updated! #{invoice_is_active_notice(@invoice)}"
      else
        flash[:error] = "unable to create following invoice. Was this invoice active?"
      end
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    elsif @invoice.update_attributes(permitted_parameters.except(:child_enabled_feature_slugs_string))
      @invoice.update_attributes(child_enabled_feature_slugs_string: permitted_parameters[:child_enabled_feature_slugs_string])
      flash[:success] = "Invoice updated! #{invoice_is_active_notice(@invoice)}"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :edit
    end
  end

  protected

  def find_organization_features
    @organization_features = OrganizationFeature.order(:name)
  end

  def permitted_parameters
    params.require(:invoice).permit(:organization_feature_ids, :amount_due, :notes, :timezone, :start_at, :end_at,
      :child_enabled_feature_slugs_string, :is_endless)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:organization_id])
    return true if @organization.present?
    flash[:error] = "Sorry! That organization doesn't exist"
    redirect_to(admin_organizations_url) && return
  end

  def find_invoice
    @invoice = @organization.invoices.find(params[:id])
  end

  def invoice_is_active_notice(invoice)
    if invoice.is_active?
      "Invoice is ACTIVE"
    else
      "Invoice is NOT active"
    end
  end
end
