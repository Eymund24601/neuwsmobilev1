# nEUws mobile v1

Flutter MVP for the nEUws mobile app.

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
- If no valid Supabase values are present, app falls back to mock data mode.

## Entry Point
- lib/main.dart

## Assets
- assets/images

## Notes
- The neuws_mobile/ folder is a legacy copy from before the rename. Ignore it.
- Performance/smoothness preload strategy doc: `docs/performance_preload_strategy.md`.
