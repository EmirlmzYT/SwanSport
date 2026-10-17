/**
 * SwanSport — Lansman Bekleme Listesi (Waitlist) & E-posta Bildirim Servisi
 * Cloudflare Pages Function (`/api/waitlist`)
 *
 * - GET  /api/waitlist : Herkese açık erken erişim sayaç özeti ve lansman durumu
 * - POST /api/waitlist :
 *     1) Varsayılan (`action: "join"`): Ziyaretçiyi `join_launch_waitlist` RPC'siyle
 *        kaydeder; `RESEND_API_KEY` tanımlıysa "Sıranız Ayrıldı" onay e-postası gönderir.
 *     2) Yöneticiler (`action: "send_launch_blast"`): Yalnız `is_platform_admin()`
 *        yetkili JWT ile bekleyen kayıtlara "SwanSport Yayında!" e-postası gönderir
 *        ve `mark_launch_waitlist_notified` RPC'sini çağırır.
 */

const ALLOWED_ORIGINS = new Set([
  'https://swansport.com.tr',
  'https://www.swansport.com.tr',
  'https://swansport.pages.dev',
  'https://konsol.swansport.com.tr',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
]);

const ROLE_LABELS = {
  athlete: 'Sporcu',
  coach: 'Antrenör',
  club_admin: 'Kulüp Yöneticisi',
  guardian: 'Veli',
  referee: 'Hakem / Gözlemci',
};

function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  const allowOrigin = ALLOWED_ORIGINS.has(origin) ? origin : 'https://swansport.com.tr';
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
    'Cache-Control': 'no-store',
  };
}

function jsonResponse(request, status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(request),
    },
  });
}

function buildConfirmationHtml(roleLabel, sportCode) {
  const sportLine = sportCode ? `<p style="margin:6px 0 0;color:#94a3b8;font-size:13px;">Seçilen branş: <strong style="color:#5eead4;">${sportCode.toUpperCase()}</strong></p>` : '';
  return `<!doctype html>
<html lang="tr">
<body style="margin:0;padding:24px;background:#0a111e;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#f8fafc;">
  <div style="max-width:540px;margin:0 auto;background:#131d2e;border:1px solid #26354d;border-radius:18px;padding:32px;">
    <div style="display:inline-block;padding:6px 12px;border-radius:999px;background:rgba(20,184,177,0.14);color:#5eead4;font-size:12px;font-weight:700;">
      SWANSPORT ERKEN ERİŞİM
    </div>
    <h1 style="margin:18px 0 10px;font-size:24px;line-height:1.3;color:#ffffff;">Sıranız ayrıldı! 🦢</h1>
    <p style="margin:0 0 16px;color:#cbd5e1;font-size:15px;line-height:1.6;">
      SwanSport mobil uygulaması ve kulüp yönetim ekosistemi App Store ve Google Play'de yayınlandığı anda ilk haberdar olacak kişiler arasındasınız.
    </p>
    <div style="background:#0a111e;border:1px solid #223047;border-radius:12px;padding:14px 16px;margin-bottom:20px;">
      <span style="font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:0.08em;">Kayıtlı Profil Rolü</span>
      <div style="font-size:16px;font-weight:700;color:#14b8b1;margin-top:4px;">${roleLabel}</div>
      ${sportLine}
    </div>
    <p style="margin:0;color:#64748b;font-size:12px;line-height:1.5;">
      Bu e-posta swansport.com.tr üzerindeki "Yayınlanınca Bana Haber Ver" talebiniz üzerine gönderilmiştir.
    </p>
  </div>
</body>
</html>`;
}

function buildLaunchBlastHtml(roleLabel, appStoreUrl, playStoreUrl) {
  const iosBtn = appStoreUrl
    ? `<a href="${appStoreUrl}" style="display:inline-block;margin:6px 8px 6px 0;padding:12px 20px;background:#14b8b1;color:#08101d;font-weight:700;text-decoration:none;border-radius:10px;">App Store'dan İndir</a>`
    : '';
  const androidBtn = playStoreUrl
    ? `<a href="${playStoreUrl}" style="display:inline-block;margin:6px 8px 6px 0;padding:12px 20px;background:#1e293b;color:#f8fafc;border:1px solid #334155;font-weight:700;text-decoration:none;border-radius:10px;">Google Play'den İndir</a>`
    : '';
  return `<!doctype html>
<html lang="tr">
<body style="margin:0;padding:24px;background:#0a111e;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#f8fafc;">
  <div style="max-width:560px;margin:0 auto;background:#131d2e;border:1px solid #26354d;border-radius:18px;padding:32px;">
    <div style="display:inline-block;padding:6px 12px;border-radius:999px;background:rgba(20,184,177,0.16);color:#5eead4;font-size:12px;font-weight:700;">
      SWANSPORT YAYINDA
    </div>
    <h1 style="margin:18px 0 12px;font-size:26px;line-height:1.25;color:#ffffff;">Sahaya çıkma vakti geldi! 🚀</h1>
    <p style="margin:0 0 18px;color:#cbd5e1;font-size:15px;line-height:1.6;">
      Erken erişim listemize <strong>${roleLabel}</strong> olarak katılmıştınız. SwanSport artık resmi olarak yayında! 60 branşta antrenman kokpiti, canlı maç skor merkezi, şeffaf kulüp kasası ve saha rezervasyonları sizi bekliyor.
    </p>
    <div style="margin:22px 0;">
      ${iosBtn}
      ${androidBtn}
      <a href="https://swansport.com.tr" style="display:inline-block;margin:6px 0;padding:12px 20px;background:#0f766e;color:#ffffff;font-weight:700;text-decoration:none;border-radius:10px;">SwanSport'u Keşfet ↗</a>
    </div>
    <p style="margin:20px 0 0;color:#64748b;font-size:12px;">© SwanSport · Sahada buluşalım.</p>
  </div>
</body>
</html>`;
}

export async function onRequestOptions({ request }) {
  return new Response(null, { status: 204, headers: corsHeaders(request) });
}

export async function onRequestGet({ request, env }) {
  const supabaseUrl = env.SUPABASE_URL;
  const supabaseKey = env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return jsonResponse(request, 503, { ok: false, error: 'Backend yapılandırması eksik' });
  }
  try {
    const [summaryRes, configRes] = await Promise.all([
      fetch(`${supabaseUrl}/rest/v1/rpc/public_waitlist_summary`, {
        method: 'POST',
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
          'Content-Type': 'application/json',
        },
        body: '{}',
      }),
      fetch(`${supabaseUrl}/rest/v1/rpc/get_public_platform_config`, {
        method: 'POST',
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
          'Content-Type': 'application/json',
        },
        body: '{}',
      }),
    ]);
    const summary = summaryRes.ok ? await summaryRes.json() : { total_count: 0 };
    const config = configRes.ok ? await configRes.json() : {};
    return jsonResponse(request, 200, {
      ok: true,
      summary,
      launch_release: config?.launch_release || null,
    });
  } catch (_) {
    return jsonResponse(request, 500, { ok: false, error: 'Durum bilgisi alınamadı' });
  }
}

export async function onRequestPost({ request, env }) {
  const supabaseUrl = env.SUPABASE_URL;
  const supabaseKey = env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) {
    return jsonResponse(request, 503, { ok: false, error: 'Backend yapılandırması eksik' });
  }

  let body;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse(request, 400, { ok: false, error: 'Geçersiz JSON gövdesi' });
  }

  const action = String(body?.action || 'join').trim();

  if (action === 'send_launch_blast') {
    const authHeader = request.headers.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return jsonResponse(request, 401, { ok: false, error: 'Yönetici oturumu gerekli' });
    }
    const listRes = await fetch(
      `${supabaseUrl}/rest/v1/launch_waitlist?select=email,role,sport_code,club_or_city&notified_at=is.null&order=created_at.asc&limit=200`,
      {
        headers: {
          apikey: supabaseKey,
          Authorization: authHeader,
        },
      },
    );
    if (!listRes.ok) {
      return jsonResponse(request, 403, { ok: false, error: 'Bekleme listesi okunamadı veya yetkiniz yok' });
    }
    const recipients = await listRes.json();
    if (!Array.isArray(recipients) || recipients.length === 0) {
      return jsonResponse(request, 200, { ok: true, sent_count: 0, message: 'Bildirim bekleyen kayıt yok.' });
    }

    if (!env.RESEND_API_KEY) {
      return jsonResponse(request, 200, {
        ok: false,
        code: 'MAIL_PROVIDER_NOT_CONFIGURED',
        pending_count: recipients.length,
        message: 'RESEND_API_KEY tanımlı değil; e-posta listesini CSV olarak dışa aktarabilir veya anahtarı Cloudflare secret olarak ekleyebilirsiniz.',
      });
    }

    const fromAddress = env.LAUNCH_FROM_EMAIL || 'SwanSport <bilgi@swansport.com.tr>';
    const sentEmails = [];
    for (const row of recipients) {
      const roleLabel = ROLE_LABELS[row.role] || 'Sporcu';
      const mailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [row.email],
          subject: 'SwanSport Yayında! Sahaya Çıkma Vakti 🦢',
          html: buildLaunchBlastHtml(roleLabel, body.app_store_url, body.play_store_url),
        }),
      });
      if (mailRes.ok) sentEmails.push(row.email);
    }

    if (sentEmails.length > 0) {
      await fetch(`${supabaseUrl}/rest/v1/rpc/mark_launch_waitlist_notified`, {
        method: 'POST',
        headers: {
          apikey: supabaseKey,
          Authorization: authHeader,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ p_emails: sentEmails }),
      });
    }

    return jsonResponse(request, 200, {
      ok: true,
      sent_count: sentEmails.length,
      total_attempted: recipients.length,
    });
  }

  // Default: join waitlist
  const email = String(body?.email || '').trim().toLowerCase();
  const role = String(body?.role || 'athlete').trim().toLowerCase();
  const sportCode = body?.sport_code ? String(body.sport_code).trim().toLowerCase() : null;
  const clubOrCity = body?.club_or_city ? String(body.club_or_city).trim() : null;
  const source = body?.source ? String(body.source).trim() : 'swansport.com.tr';

  if (!email || email.length < 5 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(request, 400, { ok: false, error: 'Lütfen geçerli bir e-posta adresi girin.' });
  }
  if (!Object.prototype.hasOwnProperty.call(ROLE_LABELS, role)) {
    return jsonResponse(request, 400, { ok: false, error: 'Lütfen geçerli bir profil rolü seçin.' });
  }

  const rpcRes = await fetch(`${supabaseUrl}/rest/v1/rpc/join_launch_waitlist`, {
    method: 'POST',
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_email: email,
      p_role: role,
      p_sport_code: sportCode,
      p_club_or_city: clubOrCity,
      p_source: source,
    }),
  });

  if (!rpcRes.ok) {
    return jsonResponse(request, 400, { ok: false, error: 'Kaydınız şu anda alınamadı, lütfen tekrar deneyin.' });
  }

  const result = await rpcRes.json();
  let emailSent = false;

  if (env.RESEND_API_KEY && !result?.already_registered) {
    try {
      const fromAddress = env.LAUNCH_FROM_EMAIL || 'SwanSport <bilgi@swansport.com.tr>';
      const mailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [email],
          subject: 'SwanSport Erken Erişim Sıranız Ayrıldı 🦢',
          html: buildConfirmationHtml(ROLE_LABELS[role] || 'Sporcu', sportCode),
        }),
      });
      emailSent = mailRes.ok;
    } catch (_) {
      emailSent = false;
    }
  }

  return jsonResponse(request, 200, {
    ok: true,
    already_registered: Boolean(result?.already_registered),
    role,
    waitlist_count: Number(result?.waitlist_count || 1),
    email_sent: emailSent,
  });
}
