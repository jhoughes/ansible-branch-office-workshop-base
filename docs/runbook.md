# Workshop Day Runbook

> **This is the day-of operations document for both instructors during the workshop itself.**
>
> Everything that happens *before* workshop day lives in [`INSTRUCTOR-SETUP.md`](../INSTRUCTOR-SETUP.md). This file is for what happens *during* the 4-hour session: minute-by-minute pacing, dual-instructor coordination, and contingency procedures for in-flight failures.
>
> Print this. Have it on the lectern. Have a copy on each instructor's laptop.

## At-a-glance section table

| Time | Section | Lead | Co | Content | Attendees |
|---|---|---|---|---|---|
| 0:00 | 1.1 | Joe + Mike | — | Welcome, scenario, finished-product demo | Watching |
| 0:10 | 1.2 | Mike | Joe (cards) | Azure portal lab topology walkthrough | Watching |
| 0:20 | 1.3 | Mike | Joe | Ansible fundamentals speed run (against attendee 99 lab) | Watching |
| 0:40 | 1.4 | Joe | Mike (floor) | **First hands-on** — preflight + port forwards + RDP | Hands on |
| 1:00 | 2.1 | Joe | Mike (floor) | First real playbook — Linux web tier | Hands on |
| 1:15 | 2.2 | Mike | Joe (floor) | Refactor into roles | Hands on |
| 1:30 | 2.3 | Mike | Joe (floor) | PowerShell + Windows automation | Hands on |
| 1:50 | 2.4 | Both | — | Multi-platform run checkpoint | Hands on |
| 2:00 | **BREAK** | | | 10 min | |
| 2:10 | 3.1 | Joe | Mike (floor) | Security hardening as code | Hands on |
| 2:30 | 3.2 | Mike | Joe (floor) | Ansible Vault & secrets | Hands on |
| 2:45 | 3.3 | Joe | Mike (floor) | Orchestration & rolling deploys | Hands on |
| 3:00 | 3.4 | Both | — | Full stack run checkpoint | Hands on |
| 3:10 | 4.1 | Mike | Joe (floor) | Testing & debugging | Hands on |
| 3:25 | 4.2 | Joe | Mike (floor) | Scaling & maintainability | Watching |
| 3:40 | 4.3 | Both | — | **Capstone** — complete the project | Hands on |
| 4:00 | 4.4 | Both | — | Wrap-up & resources | Watching |

**Lead** is the instructor on stage and on mic. **Co** is the instructor on the floor providing 1:1 attendee support during hands-on segments. The two of you swap roles roughly every 15 minutes during sections 2 and 3 to keep both energy levels up and to give the other person time to handle attendee questions.

## Section 1.4 — First hands-on lab access (the most important section)

Every attendee needs to leave 1.4 with: a working SSH connection to control, a working SSH local port forward to web1's port 80 with the page loaded in their browser, and a working SSH local port forward to mgmt1's port 3389 with an RDP session open.

**Joe leads from stage. Mike works the floor.**

The flow:
1. Take out your card (30 sec)
2. SSH to control: `ssh attendee@<your-control-ip>` (1 min)
3. Run preflight: `cd ~/workshop && ansible-playbook preflight/check.yml` — the "you just ran Ansible" ceremony (2 min)
4. SSH port forward to web1: from a *new* terminal, `ssh -L 8080:10.NN.0.10:80 attendee@<control-ip>`. Open `http://localhost:8080` in browser (4 min)
5. SSH port forward to mgmt1 RDP: `ssh -L 13389:10.NN.0.20:3389 attendee@<control-ip>`. Open RDP client to `localhost:13389`, log in with workshop_admin from card (4 min)
6. See the Windows desktop — the "holy crap it works" moment (2 min)
7. Floor support catches anyone stuck (~3 min buffer)

**Common failures and fixes:**

| Symptom | Fix |
|---|---|
| `ssh: Connection refused` | Wrong IP — show them the card again |
| `Permission denied` | Mistyped password — have them paste from card |
| Port forward "hangs" | Correct! The SSH session stays open. Open a separate browser/RDP window |
| `ERR_CONNECTION_REFUSED` for `localhost:8080` | Forward isn't running — re-run `ssh -L` in fresh terminal |
| RDP "can't connect" | Port forward isn't up — re-run `ssh -L 13389...` |
| No SSH client on Chromebook | Direct them to "Secure Shell Extension" |

## Pattern for sections 2.1 through 4.3

For each hands-on section, the lead instructor:
1. **Sets up the section** (~3-5 min): explain goal, show code on projector, point at LAB-X.Y.md
2. **Releases attendees** (~10-12 min): "you have N minutes, raise your hand if stuck"
3. **Walks the room** with the co-instructor during lab time
4. **Calls time and demos the end state** (~2 min): show what success looks like, point at the checkpoint directory

The co-instructor's job during lab time: be visible, scan for stuck attendees (closed laptops, frustrated faces, looking at others' screens), and proactively offer help.

## The break (2:00, 10 min)

**Mandatory.** Don't skip even if running behind. Use the time to refill water, scan for stuck attendees, sync briefly with each other on pacing.

**If running long:** the break is the place to recover time, not the lab sections. Cut the break to 5 minutes if you must, but don't compress hands-on time.

## Section 4.4 — Wrap-up (4:00, 10 min)

- Both on stage
- Show the final state of the project on the projector — "this is what you all built today"
- Show the resource list slide (books, videos, repos, conference talks)
- Thank the audience, thank the conference, thank each other
- Mention the repo URL one more time, written and via QR code on the slide
- "Stick around if you have questions, we'll be here for ~15 minutes after the session ends"
- Don't run over — conference rooms turn over fast

## Contingencies

### "An attendee's lab is completely broken"

- Floor instructor moves them to a **spare attendee lab** if available. The provisioning playbook includes hot spares (`attendee21` through `attendee25`) for exactly this — if they weren't claimed by walk-ups, they're available.
- Hand them the spare card from the door table.
- If no spare available, pair them with a friendly attendee who's keeping up.
- **Do not try to debug Azure issues during the workshop.** Time spent debugging one attendee's lab is time taken from the other 19.

### "A section is running long"

- Cut lab time, not teaching time. Demo the expected end state on the projector and point at the checkpoint directory — faster than waiting for everyone to type.
- Skip stretch goals at the end of each LAB-X.Y.md.
- The break is a recovery buffer — compress if needed.
- **If you fall more than 15 minutes behind by section 3.0**, drop section 3.3 (rolling deploys) entirely and use the time to make sure 3.1 and 3.2 land cleanly. Rolling deploys are the most advanced material and the easiest to cut.

### "The projector dies"

- Every attendee has the lab guides locally at `~/workshop/LAB-*.md`. They can follow along on their own screen.
- Switch to "narrate while attendees read" mode until projector is fixed.

### "An instructor needs a break"

- Just say so. The other one takes both jobs for one section. There are 16 sections; either of you can solo for 15 minutes without hurting the workshop.
- Don't power through if you're not okay. The audience can tell.

### "Someone asks a question you don't know the answer to"

- Say so. "I don't know — that's a great question, let me find out and follow up." Write it on the lectern notepad.
- Bluffing is the single fastest way to lose audience trust.
- After the workshop, follow up via the repo's issues page or the conference Slack.

### "Someone asks a question that's a deep rabbit hole"

- "Great question — let's chat after the session. I want to make sure we keep the room on track." Not rude; the rest of the room will appreciate it.
- Note their name, find them at the break or after wrap-up.

## End of session

- Thank the audience
- Take 30 seconds to mentally note what worked and what didn't — write it down before you forget
- Don't pack up too fast — the best conversations happen in the 10 minutes after the official end
