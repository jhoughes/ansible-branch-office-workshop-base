# Contributing

This repo is the source for the *Building End-to-End Automation with Ansible* workshop, maintained by Joe Houghes and Mike Nelson. It's also intentionally MIT-licensed so others can fork and adapt it for their own workshops or homelabs.

## If you're an attendee or learner

You don't need to "contribute" to use this. Fork it, clone it, take it home, adapt it for your own environment. That's what it's here for.

If you find a bug or something doesn't work as documented, please open an issue. PRs are welcome but not required — even a clear bug report is helpful.

## If you're a workshop co-maintainer (Joe / Mike)

### Branching

- `main` — the version that runs at the next workshop. Should always be in a runnable state.
- `wip/*` — work in progress branches for new sections, fixes, or experiments. Merge to `main` via PR.

### Before committing

- Run `ansible-playbook --syntax-check` on any playbook you've touched.
- Run `ansible-lint` if you have it installed.
- If you've changed code that affects a checkpoint directory, regenerate that checkpoint.
- If you've changed code that has a captured expected-output file in `docs/captures/`, regenerate that capture.

### Lab build / capture pass

Before each workshop, one of us should do a full lab build pass — provision a fresh attendee environment in Azure, run every playbook in section order, and capture the output. See `docs/captures/HOW-TO-CAPTURE.md` for the protocol.

The capture pass also serves as the integration test. If a section breaks during the capture, fix it before workshop day.

### Don't commit secrets

The `.gitignore` is comprehensive but not infallible. Specifically:

- Never commit `.vault_pass` (only the `.example` file)
- Never commit `provisioning/azure/attendee-credentials.csv`
- Never commit Azure service principal credentials
- Never commit any file containing a real password, API key, or private key

If you accidentally commit a secret, treat it as compromised: rotate the secret, force-push the cleanup, and consider it leaked. Don't try to "just delete the file" — Git history remembers.

### Versioning

We don't strictly version this repo, but if we make changes after a workshop has run, tag the pre-workshop state so attendees can come back to "the version we used at \<conference\> \<year\>". Tag format: `\<conference-name\>-\<year\>` (e.g., `codemash-2026`).
