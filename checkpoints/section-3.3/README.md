# Checkpoint: End of Section 3.3

Snapshot of the workshop repo at the end of section 3.3. New since section 3.2:

- `playbooks/06-rolling-deploy.yml` — the rolling deploy playbook with `serial: 1`, drain/return pre/post tasks, and a real `uri` health check against `/health`
- `playbooks/03-web-tier-with-roles.yml` now targets `hosts: webservers` (was `web1` in earlier sections — section 3.3 step 2 walked attendees through that change)

To use this checkpoint to recover:

```bash
cd ~/workshop/checkpoints/section-3.3

# Vault setup (same as 3.2)
cp inventory/group_vars/windows/vault.yml.example inventory/group_vars/windows/vault.yml
nano inventory/group_vars/windows/vault.yml          # paste your Windows password
ansible-vault encrypt inventory/group_vars/windows/vault.yml
cp .vault-pass.example .vault-pass

# Configure both web servers, then roll out a deploy
ansible-playbook playbooks/03-web-tier-with-roles.yml
ansible-playbook playbooks/06-rolling-deploy.yml
```
