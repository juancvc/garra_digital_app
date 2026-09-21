# RC Visual QA Checklist

**VISUAL_USER_REVIEW_REQUIRED = YES**  
**VISUAL_USER_REVIEW_COMPLETED = NO** (Cursor does not self-approve visuals)

Review each screen on a small phone and with large text where possible.

## Screens

| ID | Screen | States to check |
|----|--------|-----------------|
| A | Login | empty, validation, error |
| B | Home | no match / upcoming / Matchday / live / finished |
| C | Passport | view + edit |
| D | Polla | open / submitted / locked / scored |
| E | Matchday polls / MVP | options, results, EN VIVO / Reconectando |
| F | Muro | feed, reaction picker, post detail, comments |
| G | Check-in | map CTA, denied permission, outside radius |
| H | Missions + streak | list, progress, empty |
| I | Clans | discovery empty, detail, Tribuna, Polla, ranking, manage, invitations |
| J | Mi Historia | timeline empty/populated |
| K | Mi Año Crema + share card | year detail |
| L | Marketplace | empty, listing, store, seller, media, featured, favorites |
| M | Sponsored card | present / absent (no placeholder) |
| N | Rewards | catalog, detail, success QR, insufficient |
| O | Referrals | code, share, metrics (no referee PII) |
| P | Notifications | list, empty, unread |
| Q | Realtime indicator | EN VIVO / Reconectando / Actualizando |

## Checklist per screen

- [ ] Spacing consistent with Garra design
- [ ] No overflow / clipped text
- [ ] Safe area respected
- [ ] Keyboard does not hide primary CTA
- [ ] Small screen OK
- [ ] Long text wraps
- [ ] Large font / accessibility scaling
- [ ] Image fallback
- [ ] Cream/charcoal contrast readable
- [ ] Touch targets adequate
- [ ] Loading does not jump layout violently
- [ ] No raw Exception / Dio / HTTP 500 / enum names shown
