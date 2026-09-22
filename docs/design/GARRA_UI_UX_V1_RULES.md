# Garra Digital — UI/UX V1 Rules

**Source of truth:** [`GARRA_UI_UX_V1_REFERENCE.png`](./GARRA_UI_UX_V1_REFERENCE.png)

Cursor and future agents **implement** this design. They do **not** invent an alternate product vision.

When UI code conflicts with the reference PNG, **the PNG wins**.

When the reference shows a capability the backend does not support yet: keep the visual intent, adapt content to real APIs, and never invent endpoints or fake backends.

---

## Product vision

Garra Digital is **la comunidad digital del hincha crema**.

It must feel like:

- people, photos, posts, conversation  
- matches, passion, communities  
- businesses, events, benefits, social impact  

It must **not** feel like:

- an enterprise dashboard  
- an admin menu  
- a stack of equal-weight cards  
- a CRUD portal  
- a bank app  

---

## Navigation architecture

Bottom navigation (exactly five):

| Tab | Responsibility |
|-----|----------------|
| **Inicio** | Live social feed |
| **Comunidad** | Comunidades Cremas (mis / descubrir / cercanas) |
| **Crear** | Intention selector first — never jump straight into a form |
| **Explorar** | Discovery hub (search, events, businesses, marketplace, solidaria, benefits) |
| **Perfil** | Identity, activity, settings, logout; SUPERADMIN also gets Centro Garra |

### Inicio = social feed

Home is **not** a module menu.

Structure (screen #1):

1. Header — brand **Garra Digital**, search, notifications  
2. Compact composer — avatar + “¿Qué vive la crema hoy?” + Foto / Video / Encuesta (only if supported)  
3. Feed tabs — **Para ti** / **Siguiendo** / **Partido** (optional Cremas if supported)  
4. Vertical posts dominating the screen  
5. Occasional compact inserts (match, community, event, business, benefit, solidaria) — never a new dashboard  

### Comunidad

Screen #2: tabs **Mis comunidades** / **Descubrir** / **Cercanas**. Dense list with cover/avatar, name, members, join/member CTA.

### Crear

Screen #3: action sheet titled **¿Qué quieres crear?**

Options (only if allowed/supported):

- Publicación  
- Evento  
- Emprendimiento  
- Campaña Solidaria  
- Comunidad  

Each option: icon, color, short description → then the real form.

### Explorar

Screen #4: search + chips + image-forward sections. Does not duplicate Home.

### Marketplace

Screen #5: **Marketplace Crema**, search, category chips, visual product grid, CTA to publish.

### Detalle emprendimiento

Screen #6: hero, identity, WhatsApp / Cómo llegar, tabs Products / Reviews / Info **only if backend supports them**.

### Partido

Screen #7: special match experience (hero, countdown, prediction, pulse, recent results). Home only shows a compact insert.

### Perfil

Screen #8: cover/avatar, name, @username, level, stats (posts / followers / following), sections, **Configuración**, and visible **Cerrar sesión**.

### Centro Garra

Screen #9: admin hub for SUPERADMIN/ADMIN. Extra capability — does **not** replace the normal user experience.

### Nueva publicación

Screen #10: compact header, identity, audience if supported, textarea, media grid, options that exist in the API.

---

## Post anatomy

Reduce nested cards and borders.

Order:

1. Avatar + identity + time + menu  
2. Text  
3. Media  
4. Actions (reactions, comments, share, save)  

### Multi-image

| Count | Layout |
|------:|--------|
| 1 | Full width |
| 2 | Split |
| 3 | 1 large + 2 small |
| 4 | 2×2 grid |
| >4 | Overlay +N if domain supports |

Own posts: never block/report self.  
Others: report, block, follow, save as already supported.

**No RenderFlex overflow** on narrow screens, long usernames, large counts, or font scale.

---

## Visual system

| Token | Role |
|-------|------|
| Background | Near black |
| Primary | Garra burgundy / garnet |
| Secondary | Cream |
| Accent | Gold |
| Text | Cream / white |

Typography tokens: display, section title, body, secondary body, caption, button, chip.

Prefer:

- images and human content  
- clear hierarchy  
- intentional whitespace  

Avoid:

- border-on-border  
- every block looking like a button  
- exaggerated radii and outlines  
- giant empty voids without empty-state copy  

---

## SUPERADMIN

SUPERADMIN is a **normal user** plus admin access.

Path: **Perfil → Centro Garra (Administración)**

Never replace bottom nav or lock the user into an admin-only app.

---

## Loading / empty / error

Every important screen: **LOADING**, **CONTENT**, **EMPTY**, **ERROR**.

- Loading: skeleton or coherent spinner  
- Empty: what happened + what to do next  
- Error: human message + retry when useful  

Never show Exception, stack traces, or raw HTTP codes to users.

---

## Staging

Staging must feel populated (posts, communities, businesses, products, events, solidaria, benefits, sponsors, match). Data must feel natural — no DEMO/TEST/SEED labels in the UI.

Environment indicator must be **non-intrusive** (small badge / debug hint). No diagonal ribbon covering the product.

---

## Prohibited

- Inventing a different design than the PNG  
- Returning Home to a dashboard of module cards  
- Hiding logout  
- Separating SUPERADMIN from the normal app  
- Disabling tests, weakening asserts, or faking green builds  
- Railway / Cloudflare CLI or infra hacks in this workstream  
- `git add .`, force push, or auto merge/rebase on baseline drift  

---

## Reference checklist (10 screens)

1. Inicio (feed)  
2. Comunidades  
3. Crear (acciones)  
4. Explorar  
5. Marketplace  
6. Detalle emprendimiento  
7. Partido  
8. Perfil  
9. Centro Garra  
10. Publicar  

Implement against these screens. Share colors alone is not enough — composition must clearly match the reference.
