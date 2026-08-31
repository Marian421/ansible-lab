# Module 1: ansible.cfg and ansible-lint

## Scenario

You've been writing Ansible playbooks and roles for a few weeks now. Your project works, but every time you run a playbook you have to type:

```bash
ansible-playbook -i inventory first-playbook.yml --ask-become-pass
```

And there's no consistent style enforced. Some tasks use FQCN (fully qualified collection names like `ansible.builtin.apt`), some don't. Some roles have trailing whitespace, some don't.

A senior engineer reviews your repo and says:

> "Add an `ansible.cfg` so we don't have to pass flags every time. And run `ansible-lint` - fix whatever it complains about."

---

## Tasks

### Task 1: Create ansible.cfg

Create `ansible.cfg` at the project root with:

- Default inventory path (so you don't need `-i inventory`)
- Default privilege escalation settings (so you don't need `--ask-become-pass`)
- Roles path pointing to `./roles`
- Disable retry files (those `.retry` files are useless)
- Set a reasonable timeout

**Hint:** Read `ansible-config init --disabled -t ini` to see all options with descriptions.

### Task 2: Verify ansible.cfg works

After creating `ansible.cfg`:

```bash
# This should work WITHOUT -i inventory
ansible lab -m ping

# This should work WITHOUT --ask-become-pass
ansible-playbook first-playbook.yml
```

If either fails, fix your config.

### Task 3: Install ansible-lint

```bash
pip install ansible-lint
```

If you don't have pip:
```bash
sudo apt install python3-pip
```

### Task 4: Run ansible-lint

```bash
ansible-lint
```

It will produce warnings and errors. Read each one.

### Task 5: Fix lint issues

Fix the issues ansible-lint reports. Common ones:
- Missing `FQCN` (use `ansible.builtin.apt` instead of `apt`)
- Trailing whitespace
- Missing `name` on tasks
- Handlers that should use `ansible.builtin.systemd` instead of `service`
- Variables that should use `snake_case`

### Task 6: Verify everything still works

```bash
ansible-lint
ansible-playbook first-playbook.yml
```

Both should pass cleanly.

---

## What You're Learning

- **ansible.cfg** centralizes configuration - no more typing flags every time
- **ansible-lint** catches mistakes before they reach production
- **FQCN** (fully qualified collection names) make it clear where a module comes from
- **Code quality** matters in infrastructure - it's not just "does it work"

## Verification

1. `ansible lab -m ping` works without `-i inventory`
2. `ansible-playbook first-playbook.yml` works without `--ask-become-pass`
3. `ansible-lint` passes with no errors
4. You can explain what each ansible.cfg setting does

## Deliverables

When you're done, show me:
1. Your `ansible.cfg` file
2. Output of `ansible-lint` (clean run)
3. Output of `ansible-playbook first-playbook.yml` (successful run)
4. What you fixed and why

We'll then add an entry to `docs/learning-journal.md` and update `CONTEXT.md`.
