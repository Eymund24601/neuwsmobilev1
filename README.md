# nEUws mobile v1

Flutter MVP for the neuws mobile app.

## Run
1. flutter pub get
2. flutter run

For web auth session persistence between restarts, use a stable localhost origin:

```bash
flutter run -d edge --web-hostname=localhost --web-port=7357
```

## Run With Supabase (Local Dev)
You only do this setup once.

1. Create `.env/supabase.local.json` (use `.env/supabase.local.example.json` as template).
2. Add your Supabase project URL + anon key in that file.
3. In VS Code, run launch config: `nEUws (Supabase Local)`.

For Supabase + persistent web session in one command:

```bash
flutter run -d edge --dart-define-from-file=.env/supabase.local.json --web-hostname=localhost --web-port=7357
```

Notes:
- End users never enter keys. Keys are bundled at build time.
- If Supabase values are missing, app shows a blocking configuration error dialog instead of falling back to fake online data.
- Runtime mock mode is not supported.

## Entry Point
- lib/main.dart

## Assets
- assets/images

## Notes
- The neuws_mobile/ folder is a legacy copy from before the rename. Ignore it.
- Performance/smoothness preload strategy doc: `docs/performance_preload_strategy.md`.

## Polyglot Reader Contract
- Article bodies used for reader validation should be long-form (target: 500+ words per localization) so split-mode scrolling and sync can be tested realistically.
- Reader defaults must come from user settings (`user_settings.reading_lang_top` + `user_settings.reading_lang_bottom`), not hardcoded article language pairs.
- Tapping a word in article text should highlight that word in the tapped language and map/highlight its counterpart in the other visible language.
- Article bundle responses should carry per-localization token payloads (stable token ids + UTF-16 offsets) for the active language pair so tap mapping is deterministic and future learning features can target token/vocab ids directly.
- The 5 key words belong in the bottom key-word section; they are not the primary interaction surface for selecting unknown words in body text.
