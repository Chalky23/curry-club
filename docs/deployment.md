# Deployment

The app is live and hosted on **GitHub Pages**.

- **Live URL:** https://chalky23.github.io/curry-club/
- **Repo:** https://github.com/Chalky23/curry-club (public, required for free Pages)
- **Source:** Pages serves the `main` branch root. Deploying means committing and
  pushing to `main`; Pages rebuilds in about a minute.

## How updates happen

Jack describes a change in chat. Claude edits `index.html`, tests it, then commits and
pushes to `main`. No manual deploy step. Future sessions should be opened on this
`curry-club` folder so the repo is to hand.

## Machine setup (done once, November 2026)

- The GitHub CLI is installed at `~/.local/bin/gh` (not on PATH, so call it by full path).
- Git authenticates to GitHub through gh. The repo-local credential helper is set to the
  full gh path, so `git push` works even though gh is not on PATH:
  `credential.https://github.com.helper = !/Users/jack.white/.local/bin/gh auth git-credential`
- Git identity in this repo is a placeholder (`jack@curry-club.local`). Change it with
  `git config user.name` / `git config user.email` if you want your real name on commits.

## One wrinkle that was fixed

The `chalky23.github.io` user repo had a `CNAME` file pointing to `jackwhite.tech`, which
redirected every project page there. That domain does not resolve, so the CNAME was
removed (with Jack's agreement) and project pages now serve from `chalky23.github.io`
directly. If `jackwhite.tech` is ever set up properly, the custom domain can be added back.

## Supabase

No Supabase config is needed for the live site. Auth and data calls go straight to the
Supabase API, which accepts any origin. Only if password reset or email confirmation is
added later will the public URL need registering as the Site URL in Supabase Auth settings.
