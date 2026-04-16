# Checkpoint: End of Section 1.4

This checkpoint is intentionally empty of code changes. Section 1.4 is about **lab access**, not about modifying the workshop repo. Nothing on disk should have changed during section 1.4 except the Windows password in `inventory/group_vars/windows.yml`, which is local to your control node and not part of the checkpoint structure.

If you got lost during section 1.4 and want to verify your starting state for section 2.1:

1. Confirm `~/workshop` is in its initial state (everything as it came from `git clone`)
2. Confirm `inventory/group_vars/windows.yml` has your Windows admin password set (NOT the placeholder)
3. Run the preflight playbook one more time to confirm both hosts are reachable:
   ```bash
   cd ~/workshop
   ansible-playbook preflight/check.yml
   ```
4. If preflight passes (two ✓ marks), you're ready for section 2.1

If preflight still fails, raise your hand — the floor instructor will help you reset.
