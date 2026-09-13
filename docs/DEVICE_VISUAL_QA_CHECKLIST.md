# Noteon — Device Visual QA Checklist

Use this on a physical phone or Android emulator / iOS simulator before the next release stage.

## Environment

- [ ] Device / emulator model: _______________
- [ ] OS version: _______________
- [ ] Build type: debug / profile / release
- [ ] Fresh install and upgrade path both checked

## Notes home

- [ ] Launch → empty state looks balanced (logo, copy, margins)
- [ ] FAB does not overlap list content or nav bar
- [ ] Create note → returns to list with new row
- [ ] Multiple notes → date headers + row spacing feel even
- [ ] Long title / preview truncate with ellipsis (no overflow)
- [ ] Search expands cleanly; clear control works
- [ ] Active filter chips + clear filters
- [ ] Pull-to-refresh
- [ ] Locked note badge readable in light and dark

## Editor (keyboard critical)

- [ ] Open new note; title → Next focuses body
- [ ] Soft keyboard open: writing area remains usable
- [ ] Soft keyboard open: bottom formatting toolbar stays above keyboard
- [ ] Toolbar scrolls horizontally (no overflow / clipped icons)
- [ ] Long note scrolls under keyboard without jumping
- [ ] Image insert → gallery/camera sheets sized correctly
- [ ] Sketch insert → save returns embed; back discards
- [ ] Unsaved teal dot appears when dirty
- [ ] Back saves / discards blank draft correctly
- [ ] Locked note unlock UI centered; password dialog + keyboard OK

## Organization

- [ ] Drawer: brand header, selection states, RTL mirroring of chevrons/padding
- [ ] Manage folders: nested indent inside card (dividers still clean)
- [ ] Create / rename / delete folder dialogs
- [ ] Tags list + create / rename / delete
- [ ] Empty folders / tags states + primary CTA

## Settings

- [ ] Appearance segmented control (narrow width: icons-only OK)
- [ ] Language segmented control (EN + AR labels; no overflow)
- [ ] System / light / dark each look intentional
- [ ] Switch to Arabic: RTL lists, drawer, editor, dialogs
- [ ] About card: logo, description, version chip

## Navigation / polish

- [ ] Notes ↔ Settings tab fade feels calm (not janky)
- [ ] Page push fade/slide respects RTL direction
- [ ] Bottom nav labels not clipped in Arabic
- [ ] Dark mode: surfaces, borders, chips, locked badge contrast

## Sign-off

- [ ] No blocking visual bugs for release
- [ ] Notes for follow-up (non-blocking): _______________
