class Admin::PaymentsController < Admin::BaseController
  include SortableTable
  before_filter :find_payment, only: [:edit, :update]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @payments = Payment.includes(:user, :organization, :invoice)
                       .order(sort_column + ' ' + sort_direction).page(page).per(per_page)
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
    @payment.update_attributes(permitted_update_parameters)
    flash[:success] = "Payment updated"
    redirect_to admin_payments_path
  end

  def create
    @payment = Payment.new(permitted_create_parameters)
    valid_kind = Payment.admin_creatable_kinds.include?(permitted_create_parameters[:kind])
    if valid_kind && @payment.save
      flash[:success] = "Payment created"
      redirect_to admin_payments_path
    else
      if valid_kind
        flash[:error] = "Unable to create"
      else
        flash[:error] = "Not able to create #{permitted_create_parameters[:kind]} kind of payments"
      end
      render :new
    end
  end

  protected

  def sortable_columns
    %w(created_at user_id organization_id kind invoice_id amount_cents)
  end

  def permitted_update_parameters
    params.require(:payment).permit(:organization_id, :invoice_id)
  end

  def permitted_create_parameters
    params.require(:payment).permit(:organization_id, :invoice_id, :kind, :amount, :email, :created_at)
  end

  def find_payment
    @payment = Payment.find(params[:id])
  end
end
