=begin
*****************************************************************
* File: app/controllers/locks_controller.rb 
* Name: Class LocksController 
* Class to lock bike at case stolen 
*****************************************************************
=end

class LocksController < ApplicationController
  
  before_filter :authenticate_user

  def index
    @user = current_user
    assert_message(@user.kind_of?(User))
    assert_object_is_not_null(@user)
    @locks = LockDecorator.decorate_collection(@user.locks)
  end

  def show
    lock = find_lock 
    @lock = LockDecorator.new(lock)
  end

  def edit
    @lock = find_lock
    assert_message(@lock.kind_of?(Lock))
    assert_object_is_not_null(@lock)
  end
  
  def update
    @lock = find_lock
    assert_message(@lock.kind_of?(Lock))
    assert_object_is_not_null(@lock)
    @lock.user = current_user
    if @lock.update_attributes(params[:lock])
      redirect_to locks_url
    else
      render action: :edit, notice: "There was a problem!"
    end
  end

  def new
    @lock = Lock.new
  end

  def create
    @lock = Lock.new(params[:lock])
    @lock.user = current_user
    if @lock.save 
      flash[:notice] = "Lock created successfully!"
      redirect_to edit_lock_url(@lock)
    else
      render action: :new
    end
  end

  def destroy
    @lock = find_lock
    @lock.destroy
    redirect_to "/locks"
  end

  protected
  def find_lock
    lock = Lock.find(params[:id])
    return lock if lock.user == current_user
    flash[:notice] = "Whoops, that's not your lock!"
    redirect_to user_home_path and return
  end

end