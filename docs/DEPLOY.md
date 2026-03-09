# Deployment Workflow

## GitHub Pages (Static Site)

Deploys from `main` branch. No build step — push to main and it's live.

### Push Workflow
```bash
git add -A && git commit -m "message" && git push
```

### Post-Push Verification
1. Wait ~60s for CI to run
2. `git pull --rebase origin main`
3. Read `version.json` — report version

### Version Format
`vYYMMDD.NN H:MMa` — date + daily counter + local time.
CI bumps automatically via GitHub Action on every push. **Never bump locally.**

## Live URLs

| Environment | URL |
|---|---|
| GitHub Pages | https://cryptocoatl.github.io/flow-into-the-missions/ |
| Supabase Dashboard | https://supabase.com/dashboard/project/bjrbtfcdnpoiguhngbch |
| Supabase API | https://bjrbtfcdnpoiguhngbch.supabase.co |

## Supabase Edge Functions

Deploy with:
```bash
cd ~/flow-into-the-missions && export SUPABASE_ACCESS_TOKEN="..." && supabase functions deploy <function-name>
```
Webhook functions need `--no-verify-jwt`.

## Tailwind CSS

After adding new Tailwind classes, run: `npm run css:build`
The built output (`styles/tailwind.out.css`) is committed — GitHub Pages has no server-side build.
