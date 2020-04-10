class Admin::PaymentsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]
  before_action :find_payment, only: %i[edit update]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @payments = matching_payments.includes(:user, :organization, :invoice)
                                 .order(sort_column + " " + sort_direction)
                                 .page(page).per(per_page)
  end

  def new
    @payment = Payment.new
  end

  def show
    redirect_to edit_admin_payment_url
  end

  def edit
  end

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
    valid_method = Payment.admin_creatable_payment_methods.include?(permitted_create_parameters[:payment_method])

    if valid_method && valid_invoice_parameters? && @payment.save
      flash[:success] = "Payment created"
      redirect_to admin_payments_path
    else
      if valid_method
        flash[:error] ||= "Unable to create"
      else
        flash[:error] ||= "Not able to create #{permitted_create_parameters[:payment_method]} method of payments"
      end
      render :new
    end
  end

  helper_method :matching_payments

  protected

  def sortable_columns
    %w[created_at user_id organization_id kind payment_method invoice_id amount_cents]
  end

  def matching_payments
    return @matching_payments if defined?(@matching_payments)
    @matching_payments = Payment
    if sort_column == "invoice_id"
      @matching_payments = matching_payments.where.not(invoice_id: nil)
    elsif sort_column == "organization_id"
      @matching_payments = matching_payments.where.not(organization_id: nil)
    end
    @matching_payments = @matching_payments.where(kind: params[:search_kind]) if params[:search_kind].present?
    @matching_payments = @matching_payments.where(created_at: @time_range)
  end

  # Override earliest period date, to use 1 week before first feedback created
  def earliest_period_date
    Time.at(1417588530)
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
    params
      .require(:payment)
      .permit(:payment_method, :amount, :email, :currency, :created_at)
      .merge(invoice_parameters)
  end

  def find_payment
    @payment = Payment.find(params[:id])
  end
end
