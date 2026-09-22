# Product Refoundation QA — GARRA_10A

Manual visual QA checklist. Do **not** mark visual PASS automatically.

## Screens

| Screen | Hierarchy | Colors | Spacing | Actions | Errors | Navigation |
|--------|-----------|--------|---------|---------|--------|------------|
| Splash | mark only | burgundy deep → black | centered | — | — | → login/home |
| Login | wordmark + form | cream on night | card padded | Google + email | snackbar danger | → home |
| Inicio (no match) | greeting + Hoy + preview | V3 tokens | section gaps | Ver comunidad | section degrade | tabs preserved |
| Inicio (matchday) | match hero first | burgundy CTA | compact | match actions | retry match | tabs |
| Comunidad populated | sticky Para ti/Siguiendo/Recientes | separators, not heavy cards | feed rhythm | react/comment/share/save | banner on refresh fail | compose central |
| Comunidad empty | composer CTA + people | same | — | Buscar / Publicar | retry | |
| Composer text | Cancelar / Publicar | surface | textarea | char 220 | human R2 msg | pop |
| Composer photos | grid 1–4 | progress | toolbar Foto | retry per photo | keep draft | |
| Post own | menu sin Bloquear/Reportar | — | — | share/save/delete | — | |
| Post other | menu con Bloquear/Reportar | — | — | follow/profile | — | |
| Comments | sheet/detail | V3 | — | send | correlation | back |
| Public profile | cover/avatar/stats | gold only level | CTA Seguir | follow | 404 blocked | |
| Own profile | Editar perfil | no Seguir/Bloquear | — | edit | — | |
| Explorar | search + destinos | clean list | — | depth routes | — | |
| Comunidades | discovery ACTIVE only | — | — | create PENDING | — | |
| Mapa | existing | — | — | — | — | from Explorar |
| Marketplace | existing | — | — | — | — | from Explorar |
| Eventos | existing | — | — | — | — | from Explorar |
| Solidaria | existing | — | — | — | — | from Explorar |
| Passport | perfil tab | — | — | logout elsewhere | — | |
| Actividad | notifications | — | — | deep links | — | |
| Admin Center | Pendientes + Operación | burgundy accents | tiles | queues | gate by role | SUPERADMIN users |

## Device acceptance flow

1. Cold start → splash mark (not “PA” / not “GD” circle).
2. Login → tabs Inicio / Comunidad / Crear / Explorar / Perfil.
3. Switch tabs → scroll/state preserved.
4. Crear → composer → text + 1–4 photos → publish → appears in Recientes.
5. Own post menu → never Block/Report.
6. Other post → Block/Report available.
7. Explorar → open Map/Market without main-tab clutter.
8. SUPERADMIN → Centro Garra → communities/business/events/solidaria/marketplace/roles.

## Status

`PRODUCT_VISUAL_QA = MANUAL_REQUIRED`
