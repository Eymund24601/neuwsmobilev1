# nEUws mobile v1

Flutter MVP for the nEUws mobile app.

## Run
1. flutter pub get
2. flutter run

## Run With Supabase (Local Dev)
You only do this setup once.

1. Create `.env/supabase.local.json` (use `.env/supabase.local.example.json` as template).
2. Add your Supabase project URL + anon key in that file.
3. In VS Code, run launch config: `nEUws (Supabase Local)`.

Notes:
- End users never enter keys. Keys are bundled at build time.
- If no valid Supabase values are present, app falls back to mock data mode.

## Entry Point
- lib/main.dart

## Assets
- assets/images

## Notes
- The neuws_mobile/ folder is a legacy copy from before the rename. Ignore it.
