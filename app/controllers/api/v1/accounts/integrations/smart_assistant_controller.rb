# Custom (MyDesk): the account's smart assistant settings, the inboxes it answers on, its usage, and a test chat
class Api::V1::Accounts::Integrations::SmartAssistantController < Api::V1::Accounts::Integrations::BaseController
  SETTINGS = %i[enabled name tone instructions reply_mode handoff_when_unsure handoff_message max_replies].freeze
  MAX_TEST_MESSAGES = 20
  TEST_MESSAGE_LENGTH = 2000
  TEST_ROLES = %w[user assistant].freeze
  HISTORY_MONTHS = 6

  before_action :check_authorization
  before_action :ensure_configured, only: [:test]
  before_action :set_assistant

  def show
    render json: payload
  end

  def update
    ActiveRecord::Base.transaction do
      @assistant.update!(assistant_params)
      @assistant.sync_inbox_links!
    end
    render json: payload
  rescue ActiveRecord::RecordInvalid
    render json: { message: @assistant.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # Replies to a conversation typed in the settings page, without touching any real conversation
  def test
    result = SmartAssistant::Responder.new(assistant: @assistant, messages: test_messages, usage_kind: :test).perform
    render json: result
  end

  private

  # Every smart assistant action is admin-only, like managing any other integration
  def check_authorization
    authorize(:hook, :create?)
  end

  def set_assistant
    @assistant = SmartAssistant.for_account(Current.account)
  end

  def ensure_configured
    render json: { message: I18n.t('smart_assistant.errors.not_configured') }, status: :unprocessable_entity unless SmartAssistant::Config.configured?
  end

  def assistant_params
    params.require(:smart_assistant).permit(*SETTINGS, inbox_ids: [])
  end

  def test_messages
    messages = params.require(:messages).map { |message| message.permit(:role, :content).to_h.symbolize_keys }
    raise ActionController::BadRequest, 'messages must be user or assistant turns ending with the customer' unless valid_test?(messages)

    messages.map { |message| { role: message[:role].to_sym, content: message[:content].first(TEST_MESSAGE_LENGTH) } }
  end

  def valid_test?(messages)
    return false unless messages.size.between?(1, MAX_TEST_MESSAGES) && messages.last[:role] == 'user'

    messages.all? { |message| TEST_ROLES.include?(message[:role]) && message[:content].present? }
  end

  def payload
    {
      configured: SmartAssistant::Config.configured?,
      assistant: @assistant.slice(:id, :inbox_ids, *SETTINGS).merge(default_name: I18n.t('smart_assistant.default_name')),
      usage: usage
    }
  end

  def usage
    {
      replies_this_month: @assistant.replies_this_month,
      monthly_limit: SmartAssistant::Config.monthly_reply_limit,
      conversations_this_month: @assistant.monthly_replies.distinct.count(:conversation_id),
      handoffs_this_month: @assistant.handoffs_this_month,
      model: SmartAssistant::Config.model,
      tokens: tokens_usage
    }
  end

  # This month's tokens and cost per kind of call, and the totals of the last months
  def tokens_usage
    usages = SmartAssistant::Usage.where(account_id: Current.account.id)
    {
      this_month: usages.in_month(Time.current).totals_by_kind,
      months: usages.where(created_at: (HISTORY_MONTHS - 1).months.ago.beginning_of_month..).totals_by_month
    }
  end
end
