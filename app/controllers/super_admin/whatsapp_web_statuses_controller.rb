# Custom (MyDesk): Super Admin > Monitor > WhatsApp Web. Gateway health, version and updates, and every
# number on the gateway with its account and inbox.
class SuperAdmin::WhatsappWebStatusesController < SuperAdmin::ApplicationController
  def show
    @overview = WhatsappWeb::GatewayOverview.new
    @releases = WhatsappWeb::ReleaseCheck.new(@overview.version)
  end

  def refresh
    WhatsappWeb::ReleaseCheck.refresh!
    redirect_to super_admin_whatsapp_web_status_path, notice: t('super_admin.whatsapp_web.updates.checked')
  end

  # Only numbers whose inbox no longer exists; linked numbers are managed from the inbox settings
  def remove_number
    name = params.require(:name).to_s
    if WhatsappWeb::Config.inbox_for(name)
      redirect_to super_admin_whatsapp_web_status_path, alert: t('super_admin.whatsapp_web.numbers.still_linked')
    else
      WhatsappWeb::Client.new.delete_instance(name)
      redirect_to super_admin_whatsapp_web_status_path, notice: t('super_admin.whatsapp_web.numbers.removed', name: name)
    end
  rescue WhatsappWeb::Client::Error => e
    redirect_to super_admin_whatsapp_web_status_path, alert: e.message
  end
end
