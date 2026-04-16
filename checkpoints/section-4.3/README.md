# Checkpoint: End of Section 4.3 (Capstone — Final Workshop State)

This is the final checkpoint — the complete state of the workshop repo at the end of the 4-hour workshop.

Identical to the main `~/workshop/` directory at this point.

What's new since section 4.1:

- `playbooks/site.yml` — the capstone "build everything" playbook orchestrating all three roles across the entire branch_office

To use this checkpoint to bring up the entire branch office from scratch:

```bash
cd ~/workshop/checkpoints/section-4.3

# Vault setup (same as 3.2/3.3)
cp inventory/group_vars/windows/vault.yml.example inventory/group_vars/windows/vault.yml
nano inventory/group_vars/windows/vault.yml          # paste your Windows password
ansible-vault encrypt inventory/group_vars/windows/vault.yml
cp .vault-pass.example .vault-pass

# The single command that builds the entire branch office
ansible-playbook playbooks/site.yml
```

That's it. One command, three roles, every host configured, security baseline applied.

If you ever want to reproduce the workshop's lab on your own (homelab, future training session, etc.), this checkpoint plus `provisioning/vagrant/Vagrantfile` is everything you need.
