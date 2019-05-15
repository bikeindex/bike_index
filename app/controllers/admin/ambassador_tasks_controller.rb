class Admin::AmbassadorTasksController < Admin::BaseController
  layout "new_admin"

  before_action :find_ambassador_task, only: %w[show edit update]

  def index
    @ambassador_tasks = AmbassadorTask.all
  end

  def show; end

  def new
    @ambassador_task = AmbassadorTask.new
  end

  def create
    @ambassador_task = AmbassadorTask.new(ambassador_task_params)

    if @ambassador_task.save
      @ambassador_task.ensure_assigned_to_all_ambassadors!
      redirect_to admin_ambassador_tasks_url
    else
      flash.now[:error] = @ambassador_task.errors.full_messages.join("\n")
      render :new
    end
  end

  def edit; end

  def update
    if @ambassador_task.update(ambassador_task_params)
      redirect_to admin_ambassador_tasks_url
    else
      flash.now[:error] = @ambassador_task.errors.full_messages.join("\n")
      render :edit
    end
  end

  def destroy
    ambassador_task = AmbassadorTask.find_by(id: params[:id])

    if !ambassador_task&.destroy
      flash[:error] = "Could not delete ambassador task."
    end

    redirect_to admin_ambassador_tasks_url
  end

  private

  def ambassador_task_params
    params.require(:ambassador_task).permit(:description)
  end

  def find_ambassador_task
    @ambassador_task = AmbassadorTask.find(params[:id])
  end
end
