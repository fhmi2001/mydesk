# Custom (MyDesk): Salla sends the merchant back here after they approve (or refuse) MyDesk.
# The signed state names the MyDesk account; the code is exchanged for the store's tokens.
class Salla::CallbacksController < ApplicationController
  def show
    account = Account.find_by(id: Salla::OauthClient.account_id_from(params[:state]))
    return head :unprocessable_entity if account.blank?
    return redirect_back_with(account, 'denied') if params[:error].present? || params[:code].blank?

    Salla::ConnectService.new(account: account, code: params[:code]).perform
    redirect_back_with(account, 'connected')
  rescue Salla::ConnectService::StoreTakenError
    redirect_back_with(account, 'store_taken')
  rescue StandardError => e
    Rails.logger.error("[Salla] Callback failed: #{e.message}")
    redirect_back_with(account, 'failed')
  end

  private

  def redirect_back_with(account, result)
    redirect_to Salla::Config.integration_url(account.id, salla: result), allow_other_host: true
  end
end
