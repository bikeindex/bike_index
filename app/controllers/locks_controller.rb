class LocksController < ApplicationController
  before_filter :authenticate_user

  def index
    @user = current_user
    @locks = LockDecorator.decorate_collection(@user.locks)
  end

  def show
    lock = find_lock 
    @lock = LockDecorator.new(lock)
  end

  def edit
    @lock = find_lock
  end
  
  def update
    @lock = find_lock
    @lock.user = current_user
    if @lock.update_attributes(permitted_parameters)
      redirect_to locks_url
    else
      flash[:error] = 'There was a problem!'
      render action: :edit
    end
  end

  def new
    @lock = Lock.new
  end

  def create
    @lock = Lock.new(permitted_parameters)
    @lock.user = current_user
    if @lock.save 
      flash[:success] = "Lock created successfully!"
      redirect_to edit_lock_url(@lock)
    else
      render action: :new
    end
  end

  def destroy
    @lock = find_lock
    @lock.destroy
    redirect_to '/locks'
  end

  private

  def find_lock
    lock = Lock.find(params[:id])
    return lock if lock.user == current_user
    flash[:error] = "Whoops, that's not your lock!"
    redirect_to user_home_path and return
  end

  def permitted_parameters
    params.require(:lock).permit(Lock.old_attr_accessible)
  end
end