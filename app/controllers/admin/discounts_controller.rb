class Admin::DiscountsController < Admin::BaseController

  before_filter :find_discount, only: [:show, :edit, :update, :destroy]

  def index
    @discounts = Discount.order(params[:sort])
  end

  def show
  end

  def new
    @discount = Discount.new
  end


  def edit
  end

  def create
    # @discount = Discount.new(permitted_params.discount)
    @discount = Discount.create(params[:discount])
    if @discount.save(params[:discount])
      redirect_to admin_discounts_url, :notice => 'Discount saved.'
    else
      render action: :new
    end
  end

  def update
    # if @discount.update_attributes(permitted_params.discount)
    if @discount.update_attributes(params[:discount])
      redirect_to admin_discounts_url, :notice => 'Discount saved.'
    else
      render action: :edit
    end
  end

  def destroy
    @discount.destroy
    redirect_to admin_discounts_path, :notice => "Discount deleted."
  end

  def find_discount
    @discount = Discount.find(params[:id])
  end

end
