class MyAccount::MessagesController < ApplicationController
  include Sessionable
  before_action :authenticate_user_for_my_accounts_controller

  def index
  end

  def show
  end

  def new
  end

  def create
  end
end
