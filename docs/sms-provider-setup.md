# SwanSport — SMS Sağlayıcı & Telefon Doğrulama Kurulumu

0107 ile halka açık saha işlemleri ve partner iletişimi sunucuda telefon
doğrulaması (`phone`) veya onaylı kimlik (`id`) ister. Kulüp tesis rezervasyon
RPC'lerinin personel/üyelik koşulları ayrıca geçerlidir.

## 1. Supabase Cloud

1. Dashboard → Authentication → Providers (veya Sign In / Providers) → Phone
   bölümünde telefon sağlayıcısını etkinleştirin.
2. Twilio seçerseniz Account SID, Auth Token ve Message Service SID değerlerini
   sağlayıcının güvenli ayar alanlarına girin.
3. Netgsm / İletimerkezi gibi yerel sağlayıcılar için Authentication → Hooks →
   Send SMS Hook kullanın. Hook, Supabase'in telefon ve OTP içeren isteğini
   sağlayıcının API biçimine çeviren bir sunucu/Edge Function endpoint'i olmalıdır.
   Sağlayıcının API adresini doğrudan webhook olarak yazmak yeterli değildir;
   hook imzasını doğrulayın, sağlayıcı anahtarlarını sunucuda tutun.
4. Geliştirme projesinde Phone ayarlarında test telefonları destekleniyorsa
   `905550000000:123456` eşlemesini tanımlayın. Kullanıcı formunda
   `+905550000000` girilir; sunucu test eşlemesinde ülke kodlu, `+` içermeyen
   rakamlar kullanılır. Sabit OTP gerçek SMS göndermez. Üretim için kaldırın.

Bu uygulama mevcut hesabın telefonunu `updateUser` ile değiştirir, SMS kodunu
`OtpType.phoneChange` ile onaylar. Kurulum testini bu akışta yapın.

[Telefon sağlayıcısı](https://supabase.com/docs/guides/auth/phone-login),
[Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook).

## 2. Self-hosted Supabase / GoTrue

Docker Compose içindeki Auth servisinin adı standart kurulumda `auth`'tur;
kendi kurulumunuzdaki `gotrue` adı da kullanılabilir. Ortam değişkenlerini
servisin `environment` alanına bağlayın; yalnız `.env` içine yazmak yeterli değildir.

```env
GOTRUE_EXTERNAL_PHONE_ENABLED=true
GOTRUE_SMS_AUTOCONFIRM=false
GOTRUE_SMS_PROVIDER=twilio
GOTRUE_SMS_TWILIO_ACCOUNT_SID=ACxxxx
GOTRUE_SMS_TWILIO_AUTH_TOKEN=xxxx
GOTRUE_SMS_TWILIO_MESSAGE_SERVICE_SID=MGxxxx
GOTRUE_SMS_OTP_LENGTH=6
GOTRUE_SMS_OTP_EXP=300
GOTRUE_SMS_MAX_FREQUENCY=60s
# Yalnız geliştirme/test ortamında, üretime taşımayın:
GOTRUE_SMS_TEST_OTP=905550000000:123456,905320000000:654321
```

Değerleri bağladıktan sonra Auth servisini yeniden oluşturun. Uygulamadaki
60 saniyelik sayaç yeniden gönderme beklemesidir; kodun geçerlilik süresini
sunucu belirler. SMS sağlayıcı hatası, hatalı kod ve süre dolması ayrı
durumlardır; gerçek bir test numarasıyla gönderme, yeniden gönderme ve onayı deneyin.

[Self-hosted telefon kurulumu](https://supabase.com/docs/guides/self-hosting/self-hosted-phone-mfa).

## 3. SMS olmadan kimlik alternatifi

`/dogrulama` ekranından kimlik belgesi başvurusu yapılabilir. Yetkili platform
yöneticisi Konsol → Onaylar (`/onaylar`) üzerinden kimliği inceleyip onaylar.
`my_venue_verification_tier` onaylı kimlik kaynağını okuyarak `id` döndürür;
istemciden değiştirilebilen `profiles.verification_tier` kanıt değildir.
Kimlik onayı telefon/kimlik kapısını karşılar; kulüp üyeliği, personel,
branş belgesi ve diğer işlem yetkilerinin yerine geçmez.
