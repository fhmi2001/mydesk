# Custom (MyDesk): the home screen («لوحة التحكم»). How many open conversations have waited an hour or more for a
# reply, counted here rather than by loading the conversations themselves. It is a support report, so the manager's
# only (ReportPolicy), as the screen's other support numbers are.
class Api::V1::Accounts::HomeController < Api::V1::Accounts::BaseController
  LATE_AFTER = 1.hour

  before_action -> { authorize :report, :view? }

  def waiting
    late = Current.account.conversations.open.where(waiting_since: ..LATE_AFTER.ago)
    render json: { late_count: late.count }
  end
end
