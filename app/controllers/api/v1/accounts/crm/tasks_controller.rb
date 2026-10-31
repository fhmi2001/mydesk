# Custom (MyDesk): tasks: the tabs, one task (its direct link), create, edit, complete, reopen, delete
class Api::V1::Accounts::Crm::TasksController < Api::V1::Accounts::Crm::BaseController
  before_action :set_task, only: [:show, :update, :complete, :reopen, :destroy]

  def index
    tasks = service(SalesCrm::Tasks::List).perform(tasks_scope, kind: params[:scope].presence || 'mine', contact_id: params[:contact_id],
                                                                deal_id: params[:deal_id], page: params[:page].presence || 1)
    render json: { tasks: tasks.map { |t| SalesCrm::Presenter.task(t) }, total: tasks.total_count, page: tasks.current_page,
                   overdue_count: service(SalesCrm::Tasks::List).overdue_count(tasks_scope) }
  end

  def show
    authorize @task
    render json: SalesCrm::Presenter.task(@task)
  end

  def create
    authorize SalesCrm::Task
    render json: SalesCrm::Presenter.task(service(SalesCrm::Tasks::Create).perform(task_params))
  end

  def update
    authorize @task
    render json: SalesCrm::Presenter.task(service(SalesCrm::Tasks::Update).perform(@task, task_params))
  end

  def complete
    authorize @task
    render json: SalesCrm::Presenter.task(service(SalesCrm::Tasks::Complete).perform(@task))
  end

  def reopen
    authorize @task
    render json: SalesCrm::Presenter.task(service(SalesCrm::Tasks::Reopen).perform(@task))
  end

  def destroy
    authorize @task
    service(SalesCrm::Tasks::Destroy).perform(@task)
    head :ok
  end

  private

  def set_task
    @task = tasks_scope.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :due_at, :assignee_id, :contact_id, :deal_id, :conversation_id, :kind)
  end
end
