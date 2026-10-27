# Custom (MyDesk): headline numbers for the unified performance report (medians, previous period, channels)
class Api::V2::Accounts::PerformanceReportsController < Api::V1::Accounts::BaseController
  before_action -> { authorize :report, :view? }

  def show
    return render json: { error: 'since and until are required' }, status: :unprocessable_entity if params[:since].blank? || params[:until].blank?

    render json: V2::Reports::PerformanceBuilder.new(account: Current.account, params: params).build
  end
end
