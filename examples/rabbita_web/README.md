# Rabbita Web example

A minimal browser example that combines `lampclaw/i18n` with Rabbita. It keeps
locale and message enums in the application, builds runtime catalogs from
exhaustive translations, and renders messages with `t.t(...)`.

## Run in development

Install Warren once, then start the development server from this directory:

```bash
moon install moonbit-community/warren
warren dev
```

Open the local URL printed by Warren and use the button to switch between
English and Simplified Chinese.

## Verify

```bash
moon test --target js
warren build --dist /tmp/moonbit-i18n-rabbita-web
```
