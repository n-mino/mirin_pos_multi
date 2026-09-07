// このバージョン番号を上げると、次回オンライン時に新しいキャッシュへ切り替わる
const CACHE_VERSION = "pos-app-cache-v101";

// アプリの動作に必要な全ファイル(App Shell)
// CDNのReact/Babelも含めてキャッシュし、完全オフラインで起動できるようにする
const APP_SHELL = [
  "./",
  "./index.html",
  "./app.jsx",
  "./ledger.jsx",
  "./payroll.jsx",
  "./manifest.json",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/icon-192-maskable.png",
  "./icons/icon-512-maskable.png",
  "https://unpkg.com/react@18.3.1/umd/react.production.min.js",
  "https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js",
  "https://unpkg.com/@babel/standalone@7.24.7/babel.min.js",
  "https://unpkg.com/@supabase/supabase-js@2.114.0/dist/umd/supabase.js",
];

// SupabaseプロジェクトのAPIドメイン。座席等の生きたデータを配信するため、
// 下のfetchハンドラでは常にネットワークへ直接流し、キャッシュ配信の対象から除外する
// (supabase-jsライブラリ本体のファイル取得はunpkg経由なのでこの対象外=通常通りキャッシュされる)。
const SUPABASE_API_HOST = "ketidzbsczlxamybkedi.supabase.co";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => {
      // CDN(unpkg)はCORSに対応しているため、ページ側の<script crossorigin>と
      // 同じ既定モード(cors)で取得する。no-corsで取得するとopaqueレスポンスに
      // なり、後続の実リクエスト(corsモード)に対して返した際にモード不一致の
      // ネットワークエラーとなり、React本体が読み込めなくなってしまうため。
      return Promise.all(
        APP_SHELL.map((url) =>
          fetch(url)
            .then((res) => cache.put(url, res))
            .catch(() => {
              // 初回インストール時にオフラインだと失敗するファイルがあってもインストール自体は続行する
            })
        )
      );
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_VERSION)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// キャッシュファースト戦略: あればキャッシュから即返し、裏側で更新を試みる(stale-while-revalidate)
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  if (!event.request.url.startsWith("http")) return; // chrome-extension: 等はSWの対象外
  if (event.request.url.includes(SUPABASE_API_HOST)) return; // Supabaseへの読み取りは常にネットワーク直行(古いキャッシュを返さない)

  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request)
        .then((networkRes) => {
          if (networkRes && networkRes.status === 200) {
            const clone = networkRes.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(event.request, clone));
          }
          return networkRes;
        })
        .catch(() => cached); // オフライン時はキャッシュにフォールバック

      return cached || fetchPromise;
    })
  );
});
