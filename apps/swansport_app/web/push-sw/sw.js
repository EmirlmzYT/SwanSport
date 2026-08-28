/**
 * SwanSport — bildirim service worker'ı.
 *
 * Flutter'ın kendi service worker'ına dokunmamak için ayrı bir kapsamda
 * (`/push-sw/`) çalışır: push olayları kaydın kapsamından bağımsız olarak bu
 * worker'a düşer, böylece her Flutter sürümünde üretilen dosyayı elle
 * düzenlemek gerekmez.
 */

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = { title: 'SwanSport', body: '', url: '/bildirimler' };
  try {
    if (event.data) data = { ...data, ...event.data.json() };
  } catch (_) {
    if (event.data) data.body = event.data.text();
  }

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: { url: data.url },
      // Aynı konudan arka arkaya gelen bildirimler üst üste yığılmasın.
      tag: data.url,
      renotify: true,
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || '/';

  event.waitUntil((async () => {
    const all = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    // Uygulama zaten açıksa yeni sekme açma — mevcut pencereyi öne al.
    for (const c of all) {
      if (c.url.includes(self.location.origin)) {
        await c.focus();
        if ('navigate' in c) await c.navigate(target).catch(() => {});
        return;
      }
    }
    await self.clients.openWindow(target);
  })());
});
