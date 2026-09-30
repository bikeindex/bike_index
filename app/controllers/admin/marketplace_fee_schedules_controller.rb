# frozen_string_literal: true

module Admin
  class MarketplaceFeeSchedulesController < Admin::BaseController
    include Binxtils::SetPeriod

    before_action :set_period, only: %i[index]
    before_action :find_marketplace_fee_schedule, only: %i[edit update destroy]
    before_action :reject_started_schedule, only: %i[edit update destroy]

    def index
      @marketplace_fee_schedules = MarketplaceFeeSchedule.order(start_at: :desc)
    end

    def new
      @marketplace_fee_schedule = MarketplaceFeeSchedule.new(
        MarketplaceFeeSchedule.current&.slice(:platform_fee_percent, :platform_fee_cap_cents, :processing_fee_percent)
      )
    end

    def create
      @marketplace_fee_schedule = MarketplaceFeeSchedule.new(marketplace_fee_schedule_params)

      if @marketplace_fee_schedule.save
        flash[:success] = "Fee schedule created"
        redirect_to admin_marketplace_fee_schedules_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @marketplace_fee_schedule.update(marketplace_fee_schedule_params)
        flash[:success] = "Fee schedule updated"
        redirect_to admin_marketplace_fee_schedules_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @marketplace_fee_schedule.destroy
      flash[:success] = "Fee schedule deleted"
      redirect_to admin_marketplace_fee_schedules_path
    end

    private

    def marketplace_fee_schedule_params
      params.require(:marketplace_fee_schedule)
        .permit(:start_at, :platform_fee_percent, :platform_fee_cap, :processing_fee_percent)
    end

    def find_marketplace_fee_schedule
      @marketplace_fee_schedule = MarketplaceFeeSchedule.find(params[:id])
    end

    # readonly? would raise ReadOnlyRecord on update and destroy
    def reject_started_schedule
      return unless @marketplace_fee_schedule.readonly?

      flash[:error] = "That fee schedule has already started, so it can't be changed or deleted. Add a new one instead"
      redirect_to admin_marketplace_fee_schedules_path
    end
  end
end
