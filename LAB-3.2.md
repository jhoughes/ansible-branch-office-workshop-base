# Section 3.2 — Ansible Vault & Secrets

> **Duration:** 15 minutes
> **Presenter:** Mike (from stage) + Joe (on the floor)
> **Your goal:** Take the Windows admin password you've been hard-coding into `inventory/group_vars/windows.yml` since section 1.4 and move it into an encrypted Ansible Vault file. Stop having credentials in plaintext.

## Why this section exists

You've spent the last two hours putting a Windows admin password into a plaintext YAML file. Every time the lab guides told you to edit `windows.yml`, you wrote a credential into source-controlled source code. That's bad. **Don't do that in real life.**

Ansible Vault is the answer. Vault encrypts files at rest using a passphrase. Encrypted files can be safely committed to git — anyone who clones the repo can read the file structure but cannot decrypt the contents without the passphrase. Playbooks decrypt vault files transparently at runtime when given the passphrase, so consumers don't even know which variables came from a vault and which didn't.

This section converts the workshop to use Vault for the Windows credential. The pattern you learn here — split a group_vars file into `vars.yml` (plaintext, indirection layer) and `vault.yml` (encrypted, raw secrets) — is the canonical production pattern for managing secrets with Ansible.

The single Vault password for this workshop is on every attendee's card AND posted on a slide right now: `POWERSHELL&DEVOPS_SUMMIT_2026!`. In a real environment, attendees would each have a personal Vault password, or the password would come from an external secret store like HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault.

## What you'll do in this section

1. Look at the new directory layout for windows group_vars (vars.yml + vault.yml)
2. Create your encrypted vault.yml from the example
3. Set up the workshop Vault password file so playbooks decrypt automatically
4. Run a playbook that uses the encrypted credential — no command-line flag needed
5. Try editing the encrypted file with `ansible-vault edit`

## Step 1 — Look at the new layout

```bash
cd ~/workshop
tree inventory/group_vars/
```

You should see:

```
inventory/group_vars/
├── all.yml
├── linux.yml
└── windows/
    ├── vars.yml
    └── vault.yml.example
```

The single file `windows.yml` you've been editing is gone. In its place is a directory `windows/` containing two files. **Both files are loaded automatically** because Ansible expands a directory named after a group into "load every file in here."

Open `inventory/group_vars/windows/vars.yml`:

```bash
cat inventory/group_vars/windows/vars.yml
```

It has the WinRM connection plumbing (mostly the same as before) plus this critical line:

```yaml
ansible_password: "{{ vault_windows_admin_password }}"
```

The right side, `vault_windows_admin_password`, is defined in the encrypted vault file. The left side is what playbooks reference. **The indirection is the pattern**: playbooks have no idea whether a variable came from an encrypted file or a plaintext one.

Now look at the example vault file:

```bash
cat inventory/group_vars/windows/vault.yml.example
```

It's just a template:

```yaml
vault_windows_admin_password: "REPLACE_ME_WITH_PASSWORD_FROM_YOUR_CARD"
```

Naming convention: anything in a vault file is prefixed with `vault_` so reviewers can spot-check for "what's encrypted vs what's not" with a grep.

## Step 2 — Create your encrypted vault file

Copy the example to the real filename:

```bash
cp inventory/group_vars/windows/vault.yml.example inventory/group_vars/windows/vault.yml
```

Edit it and put your Windows admin password in:

```bash
nano inventory/group_vars/windows/vault.yml
```

Replace `REPLACE_ME_WITH_PASSWORD_FROM_YOUR_CARD` with the same Windows admin password from your card you've been using for two hours. Save and exit.

**Now encrypt it:**

```bash
ansible-vault encrypt inventory/group_vars/windows/vault.yml
```

You'll be prompted for a "New Vault password" twice. Use:

```
POWERSHELL&DEVOPS_SUMMIT_2026!
```

(Same password for everyone, also on your card and on the slide.)

After encryption, look at the file:

```bash
cat inventory/group_vars/windows/vault.yml
```

It now looks like this:

```
$ANSIBLE_VAULT;1.1;AES256
65363134613938323737313837343033653764623232393134613334356430...
616539353637336532643664383664636164663232633266396365613436...
...
```

The first line is the Vault file header. The rest is AES256-encrypted ciphertext. **You can safely commit this file to git** — without the passphrase, the contents are unreadable.

## Step 3 — Set up the workshop Vault password file

Right now, every playbook run that touches Windows would prompt you for the Vault password interactively. That's annoying. Let's tell Ansible where to find it.

There's already an example file at the repo root:

```bash
cat .vault-pass.example
```

Shows: `POWERSHELL&DEVOPS_SUMMIT_2026!`

Copy it to the real filename (which is git-ignored):

```bash
cp .vault-pass.example .vault-pass
```

`ansible.cfg` already points at this file:

```bash
grep vault_password_file ansible.cfg
```

Shows: `vault_password_file = .vault-pass`

Now Ansible will automatically read the Vault password from `.vault-pass` whenever it needs to decrypt a file. **Don't add this file to git** — it's already in `.gitignore`.

> **Why a file and not an environment variable?** Both work. `ANSIBLE_VAULT_PASSWORD_FILE=...ansible-playbook...` works too. The file is more convenient when you're running many playbooks in a row and don't want to remember to set the env var. In CI/CD, the env var is safer because it dies with the process.

## Step 4 — Run a playbook that uses the encrypted credential

The Windows playbook from section 2.3 is the easy demo:

```bash
ansible-playbook playbooks/04-windows-mgmt.yml
```

**No `--ask-vault-pass`. No `-e ansible_password=...`. No environment variable.** Ansible reads `.vault-pass`, decrypts `vault.yml` in memory, resolves `ansible_password: "{{ vault_windows_admin_password }}"`, and authenticates to mgmt1. The playbook itself has zero idea that any of this happened.

**Expected output:** the same `ok=...` recap as section 2.3 — everything is in the desired state because nothing changed in the role or its inputs. The point isn't that the run produces new changes; the point is that **the run succeeds without a plaintext password anywhere on disk.**

## Step 5 — Edit the encrypted file with `ansible-vault edit`

Here's the workflow you'll use in real life. Don't decrypt → edit → re-encrypt as separate steps (you'd risk forgetting to re-encrypt and committing a plaintext secret). Instead:

```bash
ansible-vault edit inventory/group_vars/windows/vault.yml
```

This decrypts to a temp file, opens it in `$EDITOR` (default vi/nano), waits for you to save and exit, then re-encrypts with the same key. The plaintext never touches disk persistently.

Try it: change a comment, save, exit. The file is still encrypted on disk. Run `cat` to confirm — still ciphertext.

Other Vault commands worth knowing:

| Command | What it does |
|---|---|
| `ansible-vault encrypt FILE` | Encrypt an existing plaintext file in-place |
| `ansible-vault decrypt FILE` | Decrypt an existing encrypted file in-place (rarely needed) |
| `ansible-vault view FILE` | Print decrypted contents to stdout (read-only) |
| `ansible-vault edit FILE` | Decrypt → editor → re-encrypt round-trip |
| `ansible-vault rekey FILE` | Change the password used to encrypt the file |
| `ansible-vault encrypt_string SECRET --name VARNAME` | Encrypt a single string for inline use in a playbook |

## End of section 3.2

You should now have:

- `inventory/group_vars/windows/vars.yml` — the connection plumbing and indirection layer (committed)
- `inventory/group_vars/windows/vault.yml` — your encrypted Windows credential (NOT committed)
- `.vault-pass` — the workshop Vault password file (NOT committed)
- A working `ansible-playbook playbooks/04-windows-mgmt.yml` that decrypts transparently
- The `inventory/group_vars/windows.yml` placeholder file is gone — the lab has no plaintext credentials anywhere it could be accidentally committed

You're ready for section 3.3, where we'll spin up a second web server (`web2`) and use the orchestration features of Ansible to do a rolling deployment across both web servers without dropping traffic.

## Stretch goals

- Try `ansible-vault encrypt_string 'super-secret-value' --name 'my_inline_secret'` and see what it returns. Paste the output into a playbook's `vars:` block. That's the pattern for one-off encrypted strings inline in playbooks (rather than whole files).
- Look at the geerlingguy/ansible-for-devops `examples/orchestration/inventory/group_vars/all/` directory in your spare time — it's the same `vars.yml`/`vault.yml` split applied to a real production-style orchestration scenario.
- Read about Ansible's vault ID feature: https://docs.ansible.com/ansible/latest/vault_guide/vault_managing_passwords.html#using-multiple-vault-passwords. Multiple vault IDs let you encrypt different secrets with different passwords (e.g., dev/staging/prod).

## Checkpoint

Complete state in `checkpoints/section-3.2/`. Note: the checkpoint contains the unencrypted `vault.yml.example` only — your encrypted vault.yml stays local to your control node.
