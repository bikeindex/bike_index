# frozen_string_literal: true

class Admin::ExchangeRatesController < Admin::BaseController
  include SortableTable

  before_action :find_exchange_rate, only: %w[edit update]

  def index
    @exchange_rates =
      ExchangeRate.where(filter_params).order(sort_column => sort_direction)
  end

  def new
    @exchange_rate = ExchangeRate.new
  end

  def create
    @exchange_rate = ExchangeRate.new(exchange_rate_params)

    if @exchange_rate.save
      redirect_to admin_exchange_rates_url
    else
      flash.now[:error] = @exchange_rate.errors.full_messages.to_sentence
      render :new
    end
  end

  def edit
  end

  def update
    if @exchange_rate.update(exchange_rate_params)
      redirect_to admin_exchange_rates_url
    else
      flash.now[:error] = @exchange_rate.errors.full_messages.join("\n")
      render :edit
    end
  end

  def destroy
    exchange_rate = ExchangeRate.find_by(id: params[:id])

    unless exchange_rate&.destroy
      flash[:error] = "Could not delete exchange rate."
    end

    redirect_to admin_exchange_rates_url
  end

  private

  def exchange_rate_params
    params.require(:exchange_rate).permit(:from, :to, :rate)
  end

  def find_exchange_rate
    @exchange_rate = ExchangeRate.find(params[:id])
  end

  def sortable_columns
    %w[to from rate updated_at]
  end

  def default_direction
    "asc"
  end

  def filter_params
    params
      .permit(:search_to)
      .to_h
      .map { |k, v| [k[/(?<=search_).+/].to_sym, v] }
      .to_h
  end

  helper_method :filter_params
end
