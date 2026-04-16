# Checkpoint: End of Section 3.2

Snapshot of the workshop repo at the end of section 3.2. New since the section 3.1 checkpoint:

- `inventory/group_vars/windows/` is now a directory containing `vars.yml` and `vault.yml.example`. The old `inventory/group_vars/windows.yml` is gone.
- `.vault-pass.example` at the repo root is the example Vault password file.

To use this checkpoint to recover:

```bash
cd ~/workshop/checkpoints/section-3.2
cp inventory/group_vars/windows/vault.yml.example inventory/group_vars/windows/vault.yml
nano inventory/group_vars/windows/vault.yml          # paste your Windows password
ansible-vault encrypt inventory/group_vars/windows/vault.yml
cp .vault-pass.example .vault-pass
ansible-playbook playbooks/04-windows-mgmt.yml
```
