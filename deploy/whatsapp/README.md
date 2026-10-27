# قناة واتساب عبر QR (Evolution API)

بوابة مستقلة تربط أرقام واتساب (واتساب ويب / QR) بالمنصة. تعمل كمشروع Docker منفصل
(`mydesk-whatsapp`) ولا تعدّل أي ملف من كود Chatwoot، فلا تمسّها تحديثاته.

```
واتساب ⇄ Evolution API (:8080) ⇄ Chatwoot API + صندوق وارد من نوع API
```

- الواردة: Evolution ← يكتبها في Chatwoot عبر الـ API (رمز وصول موظف).
- الصادرة: Chatwoot ← webhook صندوق الوارد ← Evolution ← واتساب.

## الملفات

| الملف | الغرض |
|---|---|
| `docker-compose.yaml` | الحاوية، الإصدار مثبّت على `v2.3.7` (لا يحتاج تفعيل ترخيص) |
| `.env.example` | الإعدادات؛ النسخة الفعلية `.env` محلية ومستثناة من git |
| `setup.sh` | ينشئ `.env` بمفتاح عشوائي، وقاعدة `evolution`، ويشغّل الحاوية |
| `create_instance.sh` | يضيف رقماً لحساب ويُنشئ صندوق الوارد فيه تلقائياً |
| `connect.sh` | يطلب QR جديداً (يصل كصورة في محادثة البوت داخل صندوق الوارد) |

## التشغيل

1. شغّل البوابة مرة واحدة:
   ```bash
   bash deploy/whatsapp/setup.sh
   ```
2. اربط المنصة بها من **Super Admin ← WhatsApp Web** (أو متغيرات `.env` الخاصة بـ Chatwoot):
   - `WHATSAPP_WEB_API_URL`: عنوان البوابة من المنصة، مثل `http://evolution-api:8080`
   - `WHATSAPP_WEB_API_KEY`: قيمة `AUTHENTICATION_API_KEY` من `deploy/whatsapp/.env`
   - `WHATSAPP_WEB_CHATWOOT_URL`: عنوان المنصة من البوابة، مثل `http://rails:3000`
3. من المنصة: **الإعدادات ← صناديق الوارد ← إضافة ← واتساب ويب**، اكتب الاسم، ثم امسح الرمز
   الظاهر من الجوال (واتساب ← الأجهزة المرتبطة ← ربط جهاز).

إن انقطع الربط لاحقاً: إعدادات صندوق الوارد ← الإعدادات ← «اتصال واتساب» لعرض رمز جديد أو فصل الرقم.

السكربتان `create_instance.sh` و`connect.sh` بديلان من سطر الأوامر للخطوة 3.

### ملفات المنصة (Custom MyDesk)

- الخلفية: `app/services/whatsapp_web/`، `app/controllers/api/v1/accounts/whatsapp_web_controller.rb`
- الواجهة: `channels/WhatsappWeb.vue`، `components/WhatsappWebConnection.vue`، `api/channel/whatsappWebChannel.js`
- نقاط ربط صغيرة في ملفات Chatwoot (معلّمة بـ `Custom (MyDesk)`): `ChannelList.vue`، `ChannelFactory.vue`،
  `ChannelItem.vue`، `ConfigurationPage.vue`، `routes.rb`، `installation_config.yml`، إعدادات Super Admin.

حذف صندوق الوارد من المنصة لا يحذف الرقم من البوابة؛ احذفه من لوحة الإدارة.

لوحة الإدارة: `http://localhost:8080/manager` (تسجيل الدخول بقيمة `AUTHENTICATION_API_KEY` من `.env`).

## الرسائل الصادرة (webhook)

يمنع Chatwoot إرسال webhooks إلى عناوين الشبكة الداخلية (حماية SSRF). لكي تصل ردود الموظفين إلى
البوابة دون فتح الشبكة كلها، أضف اسم البوابة فقط في `.env` الخاص بـ Chatwoot:

```
SAFE_FETCH_TRUSTED_HOSTS=evolution-api
```

يُسمح بهذا الاسم وحده (مطابقة تامة)، وتبقى بقية العناوين الداخلية محجوبة، ولا يُتبع أي تحويل
(redirect) منه إلى عنوان غير موثوق. التنفيذ في `lib/safe_fetch.rb` (معلّم `Custom (MyDesk)`)،
واختباراته في `spec/lib/safe_fetch_trusted_hosts_spec.rb`. البوابة تبقى غير مكشوفة على الإنترنت.

## تنبيه

الربط عبر QR غير رسمي من واتساب؛ الإرسال الجماعي قد يؤدي لحظر الرقم. للحملات والإشعارات
استخدم واتساب الرسمي (Cloud API) المدعوم في المنصة.
