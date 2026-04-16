# Speaker Notes — Per-Slide Quick Reference

> Keep on the lectern. Glance at it, don't read it. The lab guides and the runbook have the detail — this is just enough to jog your memory.

## Slide 1: Title

- Wait for the room to settle before speaking.
- "Welcome to Building End-to-End Automation with Ansible."
- DO NOT say "Is anyone already using Ansible?" — the answer doesn't change the workshop.

## Slide 2: Welcome

- Joe intro (10s), Mike intro (10s).
- Key promise: "4 hours → complete hybrid environment, automated end-to-end."
- Mention that both of you will be trading off between stage and floor.

## Slide 3: The Scenario

- "Corporate just told you there's a new branch office. You need three things."
- Walk the four bullets. Emphasize #4 — "repeatable for the next 50."
- This is the "why automate" setup; the rest of the workshop is the "how."

## Slide 4: What You'll Build Today

- Walk the three boxes left-to-right: control → web tier → management host.
- "You will only ever SSH to control. Everything else is behind it."
- "3 hosts per attendee, already running in Azure."

## Slide 5: Section Divider — Foundations

- Transition: "Let's get you into the lab."

## Slide 6: Why Ansible — Three Reasons

- 1: Agentless — "No agent on managed hosts. SSH and WinRM are already there."
- 2: Idempotent — "Run twice, get the same result. That's what makes it safe."
- 3: Linux + Windows — "You'll prove this one yourself in section 2.3."
- Do NOT oversell; the workshop itself is the proof.

## Slide 7: Your Lab Today

- "Take out your attendee card now."
- Point at the repo URL. "It's also already cloned on your control node at ~/workshop."
- "The QR code on the right goes to the same place." (Joe: replace the placeholder with a real QR before workshop day.)
- Mike: start walking the room and helping people find their cards.

## Slide 8: Ansible Fundamentals — The Speed Run

- Mike leads this from stage against attendee 99's lab.
- 6 terms, 30 seconds each. Inventory, Playbook, Module, Role, Idempotency, Facts.
- Live demo: `ansible all -m ping` from attendee 99's control node.
- "You don't need to memorize any of this. You'll use each one in the next 3 hours."

## Slide 9: Section Divider — Core Roles & Multi-Platform

- "Let's write some code." Transition to hands-on.

## Slide 10: 2.1 — First Real Playbook

- Joe leads. "Open LAB-2.1.md on your control node."
- Show the two commands on the projector.
- "When you see the status page in your browser at localhost:8080, you're done."
- Mike: floor support.

## Slide 11: 2.2 — Refactor Into Roles

- Mike leads. "Same playbook, dramatically better organization."
- Walk the before/after comparison on the slide.
- "Open LAB-2.2.md. You'll run the role version and override a default."
- Joe: floor support.

## Slide 12: 2.3 — PowerShell + Windows Automation

- Mike stays on stage. "This is the slide where Windows admins sit up."
- Walk the four module names on the left. "Recognizable, real admin tools."
- "Open LAB-2.3.md. First run takes 5-10 minutes — Chocolatey downloads packages. Don't panic."
- Joe: floor support.

## Slide 13: Section Divider — Security & Orchestration

- "10-minute break. Don't skip it. I'll see you back here in 10."

## Slide 14: 3.1 — Hardening as Code

- Joe leads. "One role, two operating systems. The dispatcher pattern."
- Point at the 9-item list. "Same checklist, different implementations."
- The validate: sshd_config callout is the key teaching moment.
- "Open LAB-3.1.md. Re-run is idempotent — changed=0 on the second run."

## Slide 15: 3.2 — Stop Putting Passwords in YAML

- Mike leads. "You've been doing it wrong all morning. Now we fix it."
- Walk the code block showing vars.yml → vault.yml indirection.
- "Next slide has the password." ADVANCE.

## Slide 16: Today's Workshop Vault Password

- Leave this slide up for ~60 seconds.
- "It's on your card too, and in .vault-pass.example in the repo."
- "In production you'd use per-person passwords or an external store."

## Slide 17: 3.3 — Rolling Deployments

- Joe leads. "serial: 1 is the magic keyword."
- Walk the code snippet — serial, max_fail_percentage, pre/post tasks.
- "The lab has no load balancer — we simulate the drain/return. The pattern is real."
- "Open LAB-3.3.md."

## Slide 18: Section Divider — Production Patterns

- "Home stretch. Two more sections and the capstone."

## Slide 19: 4.1 — Testing & Debugging

- Mike leads. "Five flags that solve >90% of broken playbooks."
- Name each flag briefly. "The one you'll use every day is --check --diff."
- "Open LAB-4.1.md. There's a broken playbook with 5 bugs. Find them."
- Joe: floor support.

## Slide 20: 4.3 — Capstone: site.yml

- Both on stage. "One playbook, one command, everything you built today."
- Walk the three phases in the code block.
- "Open LAB-4.3.md. You'll tear something down and watch site.yml rebuild it."

## Slide 21: Where to Go From Here

- Joe and Mike alternate. 30 seconds per quadrant.
- Books: Geerling is the audience-level match. Hochstein for production depth.
- Videos: Geerling's Ansible 101 is free and covers what we covered today in more detail.
- Community roles: Galaxy and dev-sec.
- Production steps: AWX, dynamic inventory, Molecule, external secrets.

## Slide 22: Thank You

- "This is what you built today."
- Show the repo URL one last time. "Take it. Run it at home. Use the patterns at work."
- "Stick around for questions."
- Don't pack up too fast.
