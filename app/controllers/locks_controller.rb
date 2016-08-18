class LocksController < ApplicationController
  layout 'application_revised'
  before_filter :authenticate_user
  before_filter :find_lock, only: [:edit, :update, :destroy]

  def edit
  end

  def update
    if @lock.update_attributes(permitted_parameters)
      render action: :edit
    else
      @page_errors = @lock.errors
      render action: :edit
    end
  end

  def new
    @lock = Lock.new
  end

  def create
    @lock = current_user.locks.build(permitted_parameters)
    if @lock.save
      flash[:success] = 'Lock created successfully!'
      redirect_to user_home_path(active_tab: 'locks')
    else
      @page_errors = @lock.errors
      render action: :new
    end
  end

  def destroy
    @lock.destroy
    redirect_to user_home_path(active_tab: 'locks')
  end

  private

  def find_lock
    @lock = current_user.locks.where(id: params[:id]).first
    unless @lock.present?
      flash[:error] = "Whoops, that's not your lock!"
      redirect_to user_home_path and return
    end
  end

  def permitted_parameters
    params.require(:lock).permit(:lock_type_id, :has_key, :has_combination, :combination, :key_serial, :manufacturer_id, :manufacturer_other, :lock_model, :notes)
  end
end
