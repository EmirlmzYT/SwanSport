/**
 * Konsolun derin bağlantıları.
 *
 * Konsol gerçek URL yolları kullanıyor (`/konsol/sporcular`,
 * `/konsol/sporcular/<id>`). Bunlar sunucuda dosya olarak yok; birinin
 * konsolun index.html'ini döndürmesi gerekiyor.
 *
 * Neden `_redirects` değil: Cloudflare, hedefi `/index.html` olan 200
 * rewrite kurallarını "sonsuz döngü" sayıp **sessizce yok sayıyor**
 * (`Parsed 0 valid redirect rules`). Projede duran eski `_redirects` de bu
 * yüzden hiç çalışmamıştı — fark edilmemişti çünkü mobil uygulama hash
 * yönlendirme kullanıyor ve rewrite'a hiç ihtiyaç duymuyor.
 *
 * Neden kök index.html yetmiyor: Pages, eşleşmeyen yolları otomatik olarak
 * köke düşürüyor. O da `/konsol/sporcular` isteğinde kullanıcıya konsol
 * yerine mobil uygulamayı gösteriyordu.
 */
export async function onRequest(context) {
  const { request, env, next } = context;
  const url = new URL(request.url);

  // Son parçada nokta varsa bu bir dosya isteği (main.dart.js, .wasm, .png…);
  // normal varlık servisine bırak.
  const last = url.pathname.split('/').pop() || '';
  if (last.includes('.')) return next();

  // Geri kalan her şey konsolun kabuğu — yönlendirmeyi go_router yapacak.
  const shell = await env.ASSETS.fetch(
    new Request(new URL('/konsol/index.html', url.origin), {
      headers: request.headers,
    }),
  );

  // Durum kodunu 200'e sabitle: tarayıcı bunu bir hata sayfası sanmasın.
  return new Response(shell.body, {
    status: 200,
    headers: shell.headers,
  });
}
