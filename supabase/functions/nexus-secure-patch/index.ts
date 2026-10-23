// NEXUS secure patch distribution. Deploy as Supabase Edge Function.
// A published encrypted patch is never served directly from public Storage.
// Requires secrets: NEXUS_PATCH_AES_KEY_B64, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// This function deliberately does not log keys, patch bodies, or device IDs.
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const bucket = "nexus-hack-content";
const maxBytes = 12 * 1024 * 1024;
const encoder = new TextEncoder();
const magic = encoder.encode("NEX1");
const base = Deno.env.get("SUPABASE_URL") || "";
const serviceSecret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const encryptionSecret = Deno.env.get("NEXUS_PATCH_AES_KEY_B64") || "";
const permittedOrigins = new Set(
  ("http://127.0.0.1:8787,http://localhost:8787," + (Deno.env.get("NEXUS_ADMIN_ORIGINS") || ""))
    .split(",").map(x => x.trim()).filter(Boolean)
);
const db = createClient(base, serviceSecret, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const cors = (req: Request) => {
  const origin = req.headers.get("origin") || "";
  return origin && permittedOrigins.has(origin)
    ? { "Access-Control-Allow-Origin": origin, "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-nexus-path",
        "Vary": "Origin" }
    : { "Vary": "Origin" };
};
const json = (req: Request, data: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(data), {
    status, headers: { "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store", ...cors(req) }
  });
const safeKey = (v: unknown) => typeof v === "string" && v.length <= 100
  ? v.trim().toUpperCase() : "";
const safeDevice = (v: unknown) => typeof v === "string" && v.length >= 12 &&
  v.length <= 160 && /^[a-zA-Z0-9._:-]+$/.test(v) ? v : "";

async function aesKey(): Promise<CryptoKey> {
  if (!encryptionSecret) throw Error("Missing NEXUS_PATCH_AES_KEY_B64 secret");
  const decoded = Uint8Array.from(atob(encryptionSecret), c => c.charCodeAt(0));
  if (decoded.byteLength !== 32) throw Error("NEXUS_PATCH_AES_KEY_B64 must decode to 32 bytes");
  return crypto.subtle.importKey("raw", decoded, "AES-GCM", false, ["encrypt", "decrypt"]);
}
async function seal(plain: Uint8Array, path: string): Promise<Uint8Array> {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const cipher = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: encoder.encode(path), tagLength: 128 },
    await aesKey(), plain
  ));
  const bytes = new Uint8Array(4 + 12 + cipher.length);
  bytes.set(magic, 0); bytes.set(nonce, 4); bytes.set(cipher, 16);
  return bytes;
}
async function open(sealed: Uint8Array, path: string): Promise<Uint8Array> {
  if (sealed.length < 32 || sealed.slice(0, 4).some((b, i) => b !== magic[i])) {
    throw Error("Unsupported encrypted patch");
  }
  return new Uint8Array(await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: sealed.slice(4, 16),
      additionalData: encoder.encode(path), tagLength: 128 },
    await aesKey(), sealed.slice(16)
  ));
}
async function isAdmin(req: Request): Promise<boolean> {
  const auth = req.headers.get("authorization") || "";
  if (!auth.startsWith("Bearer ")) return false;
  const token = auth.slice(7);
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) return false;
  const result = await db.from("license_admins")
    .select("user_id").eq("user_id", data.user.id).maybeSingle();
  return !result.error && !!result.data;
}
async function validLicense(key: string, device: string, category?: string): Promise<boolean> {
  if (!key || !device) return false;
  const { data, error } = await db.from("licenses")
    .select("status,is_active,device_id,expires_at,capabilities")
    .eq("license_key", key).maybeSingle();
  if (error || !data || !data.is_active || data.status !== "active" ||
      data.device_id !== device ||
      (data.expires_at && new Date(data.expires_at).getTime() <= Date.now())) return false;
  const caps = Array.isArray(data.capabilities) ? data.capabilities : [];
  if (category) return caps.includes("category:" + category);
  return !caps.some((c: unknown) => typeof c === "string" && c.startsWith("category:"));
}
async function upload(req: Request): Promise<Response> {
  if (!(await isAdmin(req))) return json(req, { error: "Not authorized" }, 403);
  const path = req.headers.get("x-nexus-path") || "";
  if (!/^content\/[a-f0-9-]{36}\/[a-zA-Z0-9._-]{1,120}\.nex$/.test(path))
    return json(req, { error: "Invalid encrypted storage path" }, 400);
  const length = Number(req.headers.get("content-length") || 0);
  if (length > maxBytes) return json(req, { error: "Patch exceeds 12 MiB function limit" }, 413);
  const input = new Uint8Array(await req.arrayBuffer());
  if (!input.length || input.length > maxBytes)
    return json(req, { error: "Empty or oversized patch" }, 413);
  const encrypted = await seal(input, path);
  const { error } = await db.storage.from(bucket).upload(path, encrypted, {
    upsert: false, contentType: "application/octet-stream", cacheControl: "0"
  });
  if (error) return json(req, { error: "Encrypted upload failed" }, 500);
  return json(req, { success: true, storage_path: path,
    format: "NEX1", encrypted_bytes: encrypted.byteLength }, 201);
}
async function download(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null);
  const fileId = typeof body?.content_id === "string" ? body.content_id : "";
  const device = safeDevice(body?.device_id);
  const general = safeKey(body?.app_key);
  const categoryKey = safeKey(body?.category_key);
  if (!/^[a-f0-9-]{36}$/i.test(fileId) || !device)
    return json(req, { error: "Invalid request" }, 400);
  // All downloads require an active, device-bound general app license.
  if (!(await validLicense(general, device)))
    return json(req, { error: "License verification failed" }, 403);
  const fileResult = await db.from("remote_content_files")
    .select("id,category,storage_path,sha256,is_active,deleted_at,content_type")
    .eq("id", fileId).maybeSingle();
  const file = fileResult.data;
  if (fileResult.error || !file || !file.is_active || file.deleted_at ||
      file.content_type !== "patch" || !file.storage_path.endsWith(".nex")) {
    return json(req, { error: "Secure patch unavailable" }, 404);
  }
  // A file must belong to the currently published release, never a pending edit.
  const release = await db.from("remote_content_releases").select("manifest")
    .order("version", { ascending: false }).limit(1).maybeSingle();
  const published = Array.isArray(release.data?.manifest?.files)
    ? release.data.manifest.files.find((f: { id?: string }) => f.id === file.id) : null;
  if (!published || !published.is_active || published.deleted_at ||
      published.storage_path !== file.storage_path || published.sha256 !== file.sha256) {
    return json(req, { error: "Patch not published" }, 404);
  }
  const settings = await db.from("nexus_app_settings").select("content").eq("id", "main").maybeSingle();
  const categories = Array.isArray(settings.data?.content?.categories)
    ? settings.data.content.categories : [];
  const category = categories.find((c: { id?: string }) => c.id === file.category);
  const requiresKey = category?.requires_key !== false;
  if (requiresKey && !(await validLicense(categoryKey, device, file.category))) {
    return json(req, { error: "Category license required" }, 403);
  }
  const fetched = await db.storage.from(bucket).download(file.storage_path);
  if (fetched.error || !fetched.data) return json(req, { error: "Patch unavailable" }, 404);
  const sealed = new Uint8Array(await fetched.data.arrayBuffer());
  if (sealed.length > maxBytes + 32) return json(req, { error: "Patch size invalid" }, 413);
  const plain = await open(sealed, file.storage_path);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", plain));
  const hex = [...digest].map(b => b.toString(16).padStart(2, "0")).join("");
  if (hex !== file.sha256) return json(req, { error: "Patch integrity check failed" }, 500);
  return new Response(plain, { status: 200, headers: {
    "Content-Type": "application/octet-stream", "Cache-Control": "no-store, private",
    "X-Content-Type-Options": "nosniff", ...cors(req) } });
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(req) });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);
  if (!base || !serviceSecret || !encryptionSecret)
    return json(req, { error: "Secure patch server is not configured" }, 503);
  try {
    const mode = new URL(req.url).searchParams.get("mode");
    if (mode === "upload") return await upload(req);
    if (mode === "download") return await download(req);
    return json(req, { error: "Invalid operation" }, 400);
  } catch {
    // Never return secrets or cryptographic exception details.
    return json(req, { error: "Secure patch request failed" }, 500);
  }
});
