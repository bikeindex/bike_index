class Admin::AmbassadorTasksController < Admin::BaseController
  before_action :find_ambassador_task, only: %w[edit update]

  def index
    @ambassador_tasks = AmbassadorTask.all.order(created_at: :asc)
  end

  def new
    @ambassador_task = AmbassadorTask.new
  end

  def create
    @ambassador_task = AmbassadorTask.new(ambassador_task_params)

    if @ambassador_task.save
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
    params.require(:ambassador_task).permit(:title, :description)
  end

  def find_ambassador_task
    @ambassador_task = AmbassadorTask.find(params[:id])
  end
end
