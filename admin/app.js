import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const SUPABASE_URL = "https://oxtyyazqagmfhkgprpsp.supabase.co";
const SUPABASE_KEY = "sb_publishable_IEtNXoVHdutPKd4g_ej0MA_IF-yXUR8";
const MEDIA_BUCKET = "nexus-media";
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const $ = (id) => document.getElementById(id);
const state = { categories: [], posts: [], settings: null, uploadedImagePath: null };
const iconGlyphs = {
  "square.grid.2x2": "▦", "megaphone.fill": "◖", "book.closed.fill": "▤", photo: "▧",
  "car.side.fill": "▰", "shield.lefthalf.filled": "◇", sparkles: "✦", "person.2.fill": "♧",
  "gamecontroller.fill": "⌘", link: "↗"
};

const viewTitles = { posts: "Publicaciones", categories: "Categorías", settings: "Identidad y redes" };

function escapeHTML(value = "") {
  return String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
}

function showNotice(message, error = false) {
  const notice = $("notice");
  notice.textContent = message;
  notice.classList.toggle("error-state", error);
  notice.classList.remove("hidden");
  window.clearTimeout(showNotice.timeout);
  showNotice.timeout = window.setTimeout(() => notice.classList.add("hidden"), 4500);
}

function setBusy(button, busy, busyLabel = "Guardando…") {
  if (!button.dataset.label) button.dataset.label = button.textContent;
  button.disabled = busy;
  button.textContent = busy ? busyLabel : button.dataset.label;
}

async function loadAll() {
  const [categories, posts, settings] = await Promise.all([
    supabase.from("nexus_categories").select("id,name,icon,parent_id,sort_order,is_active").order("sort_order").order("name"),
    supabase.from("nexus_posts").select("id,category_id,kind,title,body,image_url,image_path,is_published,created_at").order("created_at", { ascending: false }),
    supabase.from("nexus_settings").select("id,brand_name,tagline,discord_url,tiktok_url").eq("id", 1).maybeSingle()
  ]);
  if (categories.error) throw categories.error;
  if (posts.error) throw posts.error;
  if (settings.error) throw settings.error;
  state.categories = categories.data ?? [];
  state.posts = posts.data ?? [];
  state.settings = settings.data;
  renderCategories();
  renderPosts();
  fillCategoryOptions();
  fillSettings();
}

function fillCategoryOptions() {
  const options = ['<option value="">Sin categoría</option>', ...state.categories.map((category) =>
    `<option value="${category.id}">${escapeHTML(category.parent_id ? "↳ " : "")}${escapeHTML(category.name)}${category.is_active ? "" : " · oculta"}</option>`
  )];
  $("postCategory").innerHTML = options.join("");

  const parents = ['<option value="">Principal</option>', ...state.categories
    .filter((category) => !category.parent_id && category.id !== $("categoryId").value)
    .map((category) => `<option value="${category.id}">${escapeHTML(category.name)}</option>`)
  ];
  $("categoryParent").innerHTML = parents.join("");
}

function renderCategories() {
  const roots = state.categories.filter((category) => !category.parent_id);
  const ordered = roots.flatMap((root) => [root, ...state.categories.filter((category) => category.parent_id === root.id)]);
  const list = $("categoriesList");
  if (!ordered.length) {
    list.innerHTML = '<p class="muted">Todavía no hay categorías. Crea la primera desde el formulario.</p>';
    return;
  }
  list.innerHTML = ordered.map((category) => {
    const parent = state.categories.find((candidate) => candidate.id === category.parent_id);
    return `<article class="category-row ${parent ? "category-indent" : ""}">
      <span class="category-glyph">${iconGlyphs[category.icon] ?? "▦"}</span>
      <div class="row-copy"><strong>${escapeHTML(category.name)}</strong><span>${escapeHTML(category.icon)} · ${escapeHTML(parent?.name ?? "Principal")}${category.is_active ? "" : " · Oculta"}</span></div>
      <div class="row-actions"><button class="small-button" data-edit-category="${category.id}">Editar</button><button class="small-button" data-delete-category="${category.id}">Eliminar</button></div>
    </article>`;
  }).join("");
}

function renderPosts() {
  const query = $("searchPosts").value.trim().toLowerCase();
  const posts = state.posts.filter((post) => `${post.title} ${post.body}`.toLowerCase().includes(query));
  $("postCount").textContent = `${posts.length} publicaciones`;
  const list = $("postsList");
  if (!posts.length) {
    list.innerHTML = '<p class="muted">No hay publicaciones que coincidan.</p>';
    return;
  }
  list.innerHTML = posts.map((post) => {
    const category = state.categories.find((item) => item.id === post.category_id);
    const kind = { announcement: "Anuncio", tutorial: "Tutorial", gallery: "Galería" }[post.kind] ?? "Publicación";
    const thumb = post.image_url ? `<img src="${escapeHTML(post.image_url)}" alt="" />` : "▧";
    return `<article class="post-row">
      <div class="post-thumb">${thumb}</div>
      <div class="row-copy"><strong>${escapeHTML(post.title)}</strong><span>${escapeHTML(kind)} · ${escapeHTML(category?.name ?? "Sin categoría")} · <span class="status ${post.is_published ? "" : "draft"}">${post.is_published ? "Publicado" : "Borrador"}</span></span></div>
      <div class="row-actions"><button class="small-button" data-edit-post="${post.id}">Editar</button><button class="small-button" data-delete-post="${post.id}">Eliminar</button></div>
    </article>`;
  }).join("");
}

function fillSettings() {
  const settings = state.settings;
  $("brandName").value = settings?.brand_name ?? "NEXUS HACK";
  $("tagline").value = settings?.tagline ?? "Comunidad, novedades y guías";
  $("discordURL").value = settings?.discord_url ?? "https://discord.gg/9NUBpqNGQ";
  $("tiktokURL").value = settings?.tiktok_url ?? "";
}

function resetPostForm() {
  $("postForm").reset();
  $("postId").value = "";
  $("postFormTitle").textContent = "Nueva publicación";
  $("imageURL").value = "";
  $("imageFile").value = "";
  $("imagePreview").classList.add("hidden");
  state.uploadedImagePath = null;
}

function resetCategoryForm() {
  $("categoryForm").reset();
  $("categoryId").value = "";
  $("categoryFormTitle").textContent = "Nueva categoría";
  $("categoryActive").checked = true;
  $("categoryOrder").value = "0";
  fillCategoryOptions();
}

async function uploadImage(file) {
  if (!file) return null;
  if (!/^image\/(png|jpeg|webp)$/.test(file.type)) throw new Error("Elige una imagen PNG, JPG o WebP.");
  if (file.size > 4 * 1024 * 1024) throw new Error("La imagen supera el límite de 4 MB.");
  const extension = file.type === "image/jpeg" ? "jpg" : file.type.split("/")[1];
  const path = `${crypto.randomUUID()}.${extension}`;
  const { error } = await supabase.storage.from(MEDIA_BUCKET).upload(path, file, { cacheControl: "3600", upsert: false, contentType: file.type });
  if (error) throw error;
  const { data } = supabase.storage.from(MEDIA_BUCKET).getPublicUrl(path);
  return { path, url: data.publicUrl };
}

$("loginForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("loginError").textContent = "";
  const button = event.currentTarget.querySelector("button[type=submit]");
  setBusy(button, true, "Entrando…");
  const { error } = await supabase.auth.signInWithPassword({ email: $("email").value, password: $("password").value });
  setBusy(button, false);
  if (error) { $("loginError").textContent = "No se pudo iniciar sesión. Comprueba el acceso de administrador."; return; }
  await openAdmin();
});

async function openAdmin() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;
  $("loginView").classList.add("hidden");
  $("adminView").classList.remove("hidden");
  $("sessionEmail").textContent = user.email ?? "Sesión activa";
  try { await loadAll(); } catch (error) { showNotice(error.message || "No se pudieron cargar los datos.", true); }
}

supabase.auth.getSession().then(({ data }) => { if (data.session) openAdmin(); });

$("signOut").addEventListener("click", async () => {
  await supabase.auth.signOut();
  $("adminView").classList.add("hidden");
  $("loginView").classList.remove("hidden");
});

document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => {
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item === button));
  const view = button.dataset.view;
  for (const name of ["posts", "categories", "settings"]) $(`${name}View`).classList.toggle("hidden", name !== view);
  $("pageTitle").textContent = viewTitles[view];
}));

$("newPost").addEventListener("click", resetPostForm);
$("newCategory").addEventListener("click", resetCategoryForm);
$("refreshPosts").addEventListener("click", async () => { try { await loadAll(); showNotice("Publicaciones actualizadas."); } catch (error) { showNotice(error.message, true); } });
$("refreshCategories").addEventListener("click", async () => { try { await loadAll(); showNotice("Categorías actualizadas."); } catch (error) { showNotice(error.message, true); } });
$("searchPosts").addEventListener("input", renderPosts);

$("imageFile").addEventListener("change", (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  if (file.size > 4 * 1024 * 1024) { showNotice("La imagen supera el límite de 4 MB.", true); event.target.value = ""; return; }
  $("previewImage").src = URL.createObjectURL(file);
  $("imagePreview").classList.remove("hidden");
});

$("removeImage").addEventListener("click", () => {
  $("imageFile").value = "";
  $("imageURL").value = "";
  $("imagePreview").classList.add("hidden");
  state.uploadedImagePath = null;
});

$("postForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = event.currentTarget.querySelector("button[type=submit]");
  setBusy(button, true);
  try {
    let imageURL = $("imageURL").value.trim() || null;
    let imagePath = state.uploadedImagePath;
    const selectedFile = $("imageFile").files?.[0];
    if (selectedFile) {
      const uploaded = await uploadImage(selectedFile);
      imageURL = uploaded.url;
      imagePath = uploaded.path;
    }
    const payload = {
      kind: $("postKind").value,
      category_id: $("postCategory").value || null,
      title: $("postTitle").value.trim(),
      body: $("postBody").value.trim(),
      image_url: imageURL,
      image_path: imagePath,
      is_published: $("published").checked
    };
    const id = $("postId").value;
    const result = id
      ? await supabase.from("nexus_posts").update(payload).eq("id", id)
      : await supabase.from("nexus_posts").insert(payload);
    if (result.error) throw result.error;
    resetPostForm(); await loadAll(); showNotice("Publicación guardada.");
  } catch (error) { showNotice(error.message || "No se pudo guardar la publicación.", true); }
  finally { setBusy(button, false); }
});

$("categoryForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = event.currentTarget.querySelector("button[type=submit]");
  setBusy(button, true);
  try {
    const payload = {
      name: $("categoryName").value.trim(), icon: $("categoryIcon").value,
      parent_id: $("categoryParent").value || null,
      sort_order: Number($("categoryOrder").value || 0), is_active: $("categoryActive").checked
    };
    const id = $("categoryId").value;
    const result = id
      ? await supabase.from("nexus_categories").update(payload).eq("id", id)
      : await supabase.from("nexus_categories").insert(payload);
    if (result.error) throw result.error;
    resetCategoryForm(); await loadAll(); showNotice("Categoría guardada.");
  } catch (error) { showNotice(error.message || "No se pudo guardar la categoría.", true); }
  finally { setBusy(button, false); }
});

$("settingsForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = event.currentTarget.querySelector("button[type=submit]");
  setBusy(button, true);
  try {
    const payload = {
      id: 1, brand_name: $("brandName").value.trim(), tagline: $("tagline").value.trim(),
      discord_url: $("discordURL").value.trim() || null, tiktok_url: $("tiktokURL").value.trim() || null
    };
    const { error } = await supabase.from("nexus_settings").upsert(payload, { onConflict: "id" });
    if (error) throw error;
    await loadAll(); showNotice("Identidad guardada. Sincroniza la app para verla.");
  } catch (error) { showNotice(error.message || "No se pudo guardar la identidad.", true); }
  finally { setBusy(button, false); }
});

$("categoriesList").addEventListener("click", async (event) => {
  const editID = event.target.closest("[data-edit-category]")?.dataset.editCategory;
  const deleteID = event.target.closest("[data-delete-category]")?.dataset.deleteCategory;
  if (editID) {
    const category = state.categories.find((item) => item.id === editID);
    if (!category) return;
    $("categoryId").value = category.id; $("categoryName").value = category.name;
    $("categoryIcon").value = category.icon; $("categoryOrder").value = category.sort_order;
    $("categoryActive").checked = category.is_active; $("categoryFormTitle").textContent = "Editar categoría";
    fillCategoryOptions(); $("categoryParent").value = category.parent_id ?? "";
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
  if (deleteID && window.confirm("¿Eliminar esta categoría? Las publicaciones conservarán su contenido.")) {
    const { error } = await supabase.from("nexus_categories").delete().eq("id", deleteID);
    if (error) { showNotice(error.message, true); return; }
    await loadAll(); showNotice("Categoría eliminada.");
  }
});

$("postsList").addEventListener("click", async (event) => {
  const editID = event.target.closest("[data-edit-post]")?.dataset.editPost;
  const deleteID = event.target.closest("[data-delete-post]")?.dataset.deletePost;
  if (editID) {
    const post = state.posts.find((item) => item.id === editID);
    if (!post) return;
    $("postId").value = post.id; $("postKind").value = post.kind;
    $("postCategory").value = post.category_id ?? ""; $("postTitle").value = post.title;
    $("postBody").value = post.body; $("imageURL").value = post.image_url ?? "";
    $("published").checked = post.is_published; state.uploadedImagePath = post.image_path;
    $("postFormTitle").textContent = "Editar publicación";
    if (post.image_url) { $("previewImage").src = post.image_url; $("imagePreview").classList.remove("hidden"); }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
  if (deleteID && window.confirm("¿Eliminar esta publicación?")) {
    const post = state.posts.find((item) => item.id === deleteID);
    const { error } = await supabase.from("nexus_posts").delete().eq("id", deleteID);
    if (error) { showNotice(error.message, true); return; }
    if (post?.image_path) await supabase.storage.from(MEDIA_BUCKET).remove([post.image_path]);
    await loadAll(); showNotice("Publicación eliminada.");
  }
});

supabase.auth.onAuthStateChange((_event, session) => {
  if (!session) {
    $("adminView").classList.add("hidden");
    $("loginView").classList.remove("hidden");
  }
});
