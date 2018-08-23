class Admin::PaymentsController < Admin::BaseController
  before_filter :find_payment, only: [:edit, :update]

  def index
    @payments = Payment.order(created_at: :desc)
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
  end

  def create
    @payment
  end

  protected

  def permitted_parameters
    params.require(:payment).permit()
  end

  def find_payment
    @payment = Payment.find(params[:id])
  end
end
