class ChargesController < ApplicationController

  def new
    @amount = 699
    @b_param = BParam.find(params[:b_param_id])
  end

  def create
    @b_param = BParam.find(params[:b_param][:id])
    @amount = 699
    customer = Stripe::Customer.create(
      :email => current_user.email,
      :card  => params[:stripeToken]
    )

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => @amount,
      :description => 'Bike Index Stripe customer',
      :currency    => 'usd'
    )
    @bike = BikeCreator.new(@b_param).create_paid_bike

    flash[:notice] = "Thank you! You're card has been charged 6.99. Your bike is now protected, permanently!"
    redirect_to edit_bike_url(@bike)
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to charges_path
  end

end
