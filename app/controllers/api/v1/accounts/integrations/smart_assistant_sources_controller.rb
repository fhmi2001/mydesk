# Custom (MyDesk): the smart assistant's knowledge base: texts, questions and answers, web pages and documents
class Api::V1::Accounts::Integrations::SmartAssistantSourcesController < Api::V1::Accounts::Integrations::BaseController
  before_action :check_authorization
  before_action :ensure_configured, only: [:create, :sync]
  before_action :set_source, only: [:destroy, :sync]

  def index
    render json: { payload: assistant.sources.latest.with_attached_file.map { |source| source_json(source) } }
  end

  def create
    source = assistant.sources.new(source_params)
    assistant.save! if assistant.new_record?
    source.save!
    render json: source_json(source)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @source.destroy!
    head :ok
  end

  # Reads the source again, e.g. after the web page changed
  def sync
    @source.update!(status: :pending)
    @source.ingest_later
    render json: source_json(@source)
  end

  private

  # Managing the knowledge base is admin-only, like every integration
  def check_authorization
    authorize(:hook, :create?)
  end

  def assistant
    @assistant ||= SmartAssistant.for_account(Current.account)
  end

  def set_source
    @source = assistant.sources.find(params[:id])
  end

  def ensure_configured
    render json: { message: I18n.t('smart_assistant.errors.not_configured') }, status: :unprocessable_entity unless SmartAssistant::Config.configured?
  end

  def source_params
    permitted = params.permit(:kind, :title, :content, :url, :file)
    raise ActionController::BadRequest, 'kind is not supported' unless SmartAssistant::Source.kinds.key?(permitted[:kind])

    permitted[:title] = permitted[:file].original_filename if permitted[:file].present? && permitted[:title].blank?
    permitted[:title] = permitted[:url] if permitted[:kind] == 'website' && permitted[:title].blank?
    permitted
  end

  def source_json(source)
    source.slice(:id, :kind, :status, :title, :url, :error_message, :chunks_count)
          .merge(content: source.text? || source.faq? ? source.content : nil,
                 synced_at: source.synced_at&.to_i, created_at: source.created_at.to_i)
  end
end
