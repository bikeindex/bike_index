class Admin::PaymentsController < Admin::BaseController
  include SortableTable
  before_filter :find_payment, only: %i[edit update]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @payments = Payment.includes(:user, :organization, :invoice)
                       .order(sort_column + " " + sort_direction).page(page).per(per_page)
  end

  def invoices
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @invoices = Invoice.includes(:organization, :payments)
                       .reorder(sort_column + " " + sort_direction).page(page).per(per_page)
  end

  def new
    @payment = Payment.new
  end

  def show
    redirect_to edit_admin_payment_url
  end

  def edit; end

  def update
    if valid_invoice_parameters?
      @payment.update_attributes(invoice_parameters) # invoice params are the only params permitted for update ;)
      flash[:success] = "Payment updated"
      redirect_to admin_payments_path
    else
      redirect_to edit_admin_payment_url(@payment.attributes = invoice_parameters)
    end
  end

  def create
    @payment = Payment.new(permitted_create_parameters)
    valid_kind = Payment.admin_creatable_kinds.include?(permitted_create_parameters[:kind])
    if valid_kind && valid_invoice_parameters? && @payment.save
      flash[:success] = "Payment created"
      redirect_to admin_payments_path
    else
      if valid_kind
        flash[:error] ||= "Unable to create"
      else
        flash[:error] ||= "Not able to create #{permitted_create_parameters[:kind]} kind of payments"
      end
      render :new
    end
  end

  protected

  def sortable_columns # sortable columns for both payments and invoices ;)
    %w[id created_at user_id organization_id kind invoice_id amount_cents
       subscription_start_at subscription_end_at amount_due_cents amount_paid_cents id]
  end

  def valid_invoice_parameters?
    invoice_parameters # To parse the invoice params
    return true unless @params_invoice.present?
    return true if @params_invoice.organization_id == invoice_parameters[:organization_id]
    organization_name = Organization.friendly_find(invoice_parameters[:organization_id])&.short_name
    flash[:error] = "Invoice #{invoice_parameters[:invoice_id]} is not owned by #{organization_name}"
    false
  end

  def invoice_parameters
    return @invoice_parameters if defined?(@invoice_parameters)
    iparams = params.require(:payment).permit(:organization_id, :invoice_id)
    @params_invoice = Invoice.friendly_find(iparams[:invoice_id])
    if @params_invoice.present?
      iparams[:organization_id] = @params_invoice.organization_id unless iparams[:organization_id].present?
    end
    @invoice_parameters = { invoice_id: @params_invoice&.id, organization_id: iparams[:organization_id]&.to_i }
  end

  def permitted_create_parameters
    params.require(:payment).permit(:kind, :amount, :email, :created_at).merge(invoice_parameters)
  end

  def find_payment
    @payment = Payment.find(params[:id])
  end
end
