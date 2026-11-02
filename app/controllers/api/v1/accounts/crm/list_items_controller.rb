# Custom (MyDesk): the Sales CRM's managed lists (?list= lead_source | product | competitor | region | industry).
# Everyone reads the active items (the deal form's pickers); administrators add, rename, reorder and archive.
# Archiving keeps the item on the deals that already have it, so old reports keep their names.
class Api::V1::Accounts::Crm::ListItemsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin, except: [:index]
  before_action :set_list
  before_action :set_item, only: [:update, :destroy]

  def index
    SalesCrm::ListItem.ensure_defaults!(Current.account, @list)
    render json: items_json
  end

  def create
    items.create!(name: params.require(:name), position: (items.maximum(:position) || -1) + 1)
    render json: items_json
  rescue ActiveRecord::RecordInvalid => e
    raise SalesCrm::ValidationError, e.record.errors.full_messages.to_sentence
  end

  def update
    @item.update!(name: params.require(:name))
    render json: items_json
  rescue ActiveRecord::RecordInvalid => e
    raise SalesCrm::ValidationError, e.record.errors.full_messages.to_sentence
  end

  def destroy
    @item.archive!
    render json: items_json
  end

  # ids: the list's items in their new order
  def reorder
    ids = Array(params.require(:ids)).map(&:to_i)
    ActiveRecord::Base.transaction do
      items.where(id: ids).find_each { |item| item.update!(position: ids.index(item.id)) }
    end
    render json: items_json
  end

  private

  def check_admin
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def set_list
    @list = params[:list].presence || Current.account.crm_list_items.find_by(id: params[:id])&.list
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_list') unless SalesCrm::ListItem::LISTS.include?(@list)
  end

  def set_item
    @item = items.find(params[:id])
  end

  def items
    SalesCrm::ListItem.for_list(Current.account, @list)
  end

  def items_json
    items.reload.map { |item| { id: item.id, list: item.list, name: item.name, position: item.position } }
  end
end
