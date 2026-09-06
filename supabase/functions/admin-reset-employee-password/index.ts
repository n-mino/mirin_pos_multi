// 管理者が従業員のパスワードを再発行するEdge Function。
// - 呼び出し元(caller)が承認済み管理者(role=admin, approved=true, active=true)であることを
//   service_role権限で確認してから、対象従業員のパスワードを新しい仮パスワードに書き換える。
// - 仮パスワードは英数字(小文字)6文字のランダム生成。
// - service_role相当の操作(Supabase Authのパスワード直接変更)はクライアント側からは
//   絶対に行えないため、この関数(サーバー側)でのみ実行する。

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function randomTempPassword(length = 6) {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let out = "";
  for (let i = 0; i < length; i++) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { employeeId } = await req.json();
    if (!employeeId) {
      return new Response(JSON.stringify({ error: "employeeIdは必須です" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "認証情報がありません" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 呼び出し元の本人確認(このリクエストのAuthorizationヘッダーが有効なセッションか)
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "セッションが無効です" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // RLSを経由せずemployeesテーブルを直接確認・更新するためのservice_roleクライアント
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // 呼び出し元が承認済み管理者であることを確認(なりすまし・権限昇格を防止)
    const { data: callerEmp, error: callerErr } = await adminClient
      .from("employees")
      .select("role, approved, active")
      .eq("auth_user_id", userData.user.id)
      .maybeSingle();
    if (callerErr || !callerEmp || callerEmp.role !== "admin" || !callerEmp.approved || !callerEmp.active) {
      return new Response(JSON.stringify({ error: "権限がありません(管理者のみ実行できます)" }), {
        status: 403,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 対象従業員のauth_user_idを取得
    const { data: targetEmp, error: targetErr } = await adminClient
      .from("employees")
      .select("auth_user_id, name")
      .eq("id", employeeId)
      .maybeSingle();
    if (targetErr || !targetEmp?.auth_user_id) {
      return new Response(JSON.stringify({ error: "対象の従業員(ログインアカウント)が見つかりません" }), {
        status: 404,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const tempPassword = randomTempPassword(6);

    const { error: updateErr } = await adminClient.auth.admin.updateUserById(targetEmp.auth_user_id, {
      password: tempPassword,
    });
    if (updateErr) {
      return new Response(JSON.stringify({ error: updateErr.message }), {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ tempPassword, name: targetEmp.name }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
