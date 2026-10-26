# Custom (MyDesk): numbers of SMS campaigns.
# - preview: checks the numbers of a new campaign before it is created. Typed text and uploaded .xlsx/.csv numbers
#   are cleaned (Saudi mobiles, 966 added, duplicates dropped) and returned; contact labels are only counted.
# - index: the numbers of an existing campaign with their delivery result and provider ids, page by page.
class Api::V1::Accounts::Campaigns::SmsRecipientsController < Api::V1::Accounts::BaseController
  # Typed numbers may be separated by new lines, commas (Latin or Arabic), semicolons or tabs
  TYPED_SEPARATORS = /[\n\r,،;\t]+/
  PER_PAGE = 50

  def index
    campaign = Current.account.campaigns.find_by!(display_id: params[:campaign_id])
    authorize campaign, :show?

    recipients = filtered_recipients(campaign)
    page = [params[:page].to_i, 1].max

    render json: {
      meta: { count: recipients.count, page: page, per_page: PER_PAGE },
      payload: recipients.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |recipient| recipient_json(recipient) }
    }
  end

  def preview
    authorize Campaign, :create?

    result = Sms::RecipientListBuilder.new(typed_numbers + file_numbers).perform
    render json: result.as_json.merge(label_recipients_count: label_numbers.uniq.size)
  rescue Sms::RecipientFileReader::InvalidFile => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def filtered_recipients(campaign)
    recipients = campaign.sms_campaign_recipients.order(:id)
    SmsCampaignRecipient.statuses.key?(params[:status]) ? recipients.where(status: params[:status]) : recipients
  end

  def recipient_json(recipient)
    recipient.slice(:id, :phone_number, :status, :source_id, :provider_request_id, :error_message)
             .merge(sent_at: recipient.sent_at&.to_i, updated_at: recipient.updated_at.to_i)
  end

  def typed_numbers
    params[:numbers].to_s.split(TYPED_SEPARATORS)
  end

  def file_numbers
    return [] if params[:file].blank?

    Sms::RecipientFileReader.new(params[:file]).numbers
  end

  def label_numbers
    label_ids = Array(params[:label_ids]).compact_blank
    return [] if label_ids.empty?

    titles = Current.account.labels.where(id: label_ids).pluck(:title)
    Current.account.contacts.tagged_with(titles, any: true).where.not(phone_number: [nil, '']).pluck(:phone_number)
  end
end
