class Admin::PaymentsController < Admin::BaseController
  include SortableTable

  before_action :find_payment, only: %i[edit update]

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @payments = pagy(matching_payments.includes(:user, :organization, :invoice)
      .order(sort_column + " " + sort_direction), limit: @per_page, page: permitted_page)
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
    if assign_to_membership_param?
      if @payment.can_assign_to_membership?
        Users::CreateOrUpdateMembershipFromPaymentJob.new.perform(@payment.id, current_user.id)
        flash[:success] = "Payment updated"
      else
        flash[:error] = "This payment can't be assigned to a membership - maybe it already has been?"
      end
      redirect_back(fallback_location: edit_admin_payment_url(@payment))
    elsif valid_invoice_parameters?
      @payment.update(invoice_parameters) # invoice params are the only params permitted for update ;)
      flash[:success] = "Payment updated"
      redirect_to admin_payments_path
    else
      redirect_to edit_admin_payment_url(@payment.attributes = invoice_parameters)
    end
  end

  def create
    @payment = Payment.new(permitted_create_parameters)
    @payment.paid_at = @payment.created_at
    valid_method = Payment.admin_creatable_payment_methods.include?(permitted_create_parameters[:payment_method])

    if valid_method && valid_invoice_parameters? && @payment.save
      flash[:success] = "Payment created"
      redirect_to admin_payments_path
    else
      flash[:error] ||= if valid_method
        "Unable to create"
      else
        "Not able to create #{permitted_create_parameters[:payment_method]} method of payments"
      end
      render :new
    end
  end

  helper_method :matching_payments

  protected

  def sortable_columns
    %w[created_at user_id organization_id kind payment_method invoice_id amount_cents referral_source]
  end

  def searchable_payment_methods
    ["show"] + Payment.payment_methods
  end

  def searchable_kinds
    ["organization"] + Payment.kinds
  end

  def matching_payments
    return @matching_payments if defined?(@matching_payments)

    matching_payments = Payment
    if sort_column == "invoice_id"
      matching_payments = matching_payments.where.not(invoice_id: nil)
    elsif sort_column == "organization_id"
      matching_payments = matching_payments.where.not(organization_id: nil)
    end
    matching_payments = matching_payments.where(organization_id: current_organization.id) if current_organization.present?

    if %w[all incomplete].include?(params[:search_incompleteness])
      @incompleteness = params[:search_incompleteness]
      matching_payments = matching_payments.incomplete if @incompleteness == "only_incomplete"
    else
      @incompleteness ||= "paid" # Default to only completed
      matching_payments = matching_payments.paid
    end
    if searchable_kinds.include?(params[:search_kind])
      @kind = params[:search_kind]

      matching_payments = if @kind == "organization"
        matching_payments.where.not(organization_id: nil)
      else
        matching_payments.where(kind: @kind)
      end
    end
    if searchable_payment_methods.include?(params[:search_payment_method])
      @render_method = true
      @payment_method = params[:search_payment_method]
      if @payment_method != "show"
        matching_payments = matching_payments.where(payment_method: @payment_method)
      end
    else
      @payment_method = "all"
    end
    if params[:search_membership_id].present?
      matching_payments = matching_payments.where(membership_id: params[:search_membership_id])
    end
    matching_payments = matching_payments.admin_search(params[:query]) if params[:query].present?
    if params[:search_email].present?
      matching_payments = matching_payments.where("email ILIKE ?", "%#{EmailNormalizer.normalize(params[:search_email])}%")
    end
    if params[:user_id].present?
      matching_payments = matching_payments.where(user_id: user_subject&.id || params[:user_id])
    end
    @matching_payments = matching_payments.where(created_at: @time_range)
  end

  # Override earliest period date, to use 1 week before first feedback created
  def earliest_period_date
    Time.at(1417588530)
  end

  def default_period
    "year"
  end

  def assign_to_membership_param?
    Binxtils::InputNormalizer.boolean(params[:assign_to_membership])
  end

  def valid_invoice_parameters?
    invoice_parameters # To parse the invoice params
    return true unless @params_invoice.present?
    return true if @params_invoice.organization_id&.to_s == invoice_parameters[:organization_id]&.to_s

    organization_name = Organization.friendly_find(invoice_parameters[:organization_id])&.short_name
    flash[:error] = "Invoice #{invoice_parameters[:invoice_id]} is not owned by #{organization_name}"
    false
  end

  def invoice_parameters
    return @invoice_parameters if defined?(@invoice_parameters)

    iparams = params.require(:payment).permit(:organization_id, :invoice_id, :referral_source)
    @params_invoice = Invoice.friendly_find(iparams[:invoice_id])
    if @params_invoice.present?
      iparams[:organization_id] = @params_invoice.organization_id unless iparams[:organization_id].present?
    end
    @invoice_parameters = iparams.slice(:organization_id, :referral_source).merge(invoice_id: @params_invoice&.id)
  end

  def permitted_create_parameters
    params
      .require(:payment)
      .permit(:payment_method, :amount, :email, :currency_enum, :created_at, :referral_source)
      .merge(invoice_parameters)
  end

  def find_payment
    @payment = Payment.find(params[:id])
  end
end
