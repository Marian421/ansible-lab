# Module 6: Docker Fundamentals — the *Why*, not the *How*

## Scenario

You already write Dockerfiles. Yours ship. So a colleague looking at your image asks:

> "Your CI takes four minutes to rebuild after a one-line source change. Why is it reinstalling
> every npm dependency every time? And why is this thing running as root?"

You can *use* Docker. This module is about understanding what it's actually doing, so you can
answer that question instead of trying things until the build gets faster.

---

## Why this module exists

A calibration on 2026-09-05 found you were solid on container networking — service-name
resolution, why `postgres:5432` resolves inside a Compose network — which lines up exactly with
having authored the Marketplace Compose file.

The gap is the rest: **layer caching, multi-stage rationale, and volume semantics.** You have
working Dockerfiles in three repos, but they work by pattern-matching rather than by
understanding. That is fine, and extremely common — but it breaks down the moment something is
slow, too big, or insecure, and it is exactly what a technical interviewer probes.

Everything here uses **your own code**. No tutorial apps.

---

## The subject: your own Dockerfile

This is the Dockerfile you wrote in `learn-cicd-typescript-starter` — the one deploying to
Cloud Run right now:

```dockerfile
FROM --platform=linux/amd64 node:18-slim

WORKDIR /usr/src/app

ADD . .

RUN npm ci

RUN npm run build

CMD ["node", "dist/main.js"]
```

It works. It also has **five** distinct problems. By the end of this module you should be able to
name all five without looking. Don't scroll ahead and guess — the tasks will surface them.

---

## Tasks

### Task 1: Establish a baseline

Clone the repo and measure what you currently have. You cannot claim an improvement you did not
measure.

```bash
git clone git@github.com:Marian421/learn-cicd-typescript-starter.git
cd learn-cicd-typescript-starter

# Build it and time it
time docker build -t notely:baseline .

# How big?
docker images notely:baseline

# How many layers, and what did each cost?
docker history notely:baseline
```

**Write down:** total size, build time, layer count.

`docker history` is the important one. Read it top to bottom and find which single layer
contributes the most megabytes. Ask yourself whether that content needs to be in the final image
at all.

### Task 2: Feel the cache miss

Make a trivial source change and rebuild.

```bash
echo "// touch" >> src/main.ts
time docker build -t notely:baseline .
```

It reinstalled every dependency. **Understand precisely why before continuing.**

The rule: each instruction creates a layer. Docker reuses a cached layer only if that instruction
*and every instruction before it* are unchanged. For `COPY`/`ADD`, "unchanged" means the copied
file contents are identical.

`ADD . .` copies your whole source tree — so changing any file invalidates that layer, and
therefore invalidates `RUN npm ci` after it. Your dependencies did not change, but Docker cannot
know that, because you told it the dependency step depends on all your source.

**Fix the ordering.** Copy the manifests, install, *then* copy source:

```dockerfile
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
```

Rebuild twice, changing a source file in between. The `npm ci` layer should now be cached.

**Record the new build time.** This is the single highest-value Docker concept there is.

### Task 3: Stop shipping your junk

There is no `.dockerignore` in that repo. So `ADD . .` copies `node_modules/`, `.git/`, and
anything else lying around into the build context — and `.git` on an active repo is not small.

```bash
# See how much you're sending to the daemon
du -sh .
```

Create `.dockerignore`:

```
node_modules
npm-debug.log
.git
.gitignore
.env
dist
coverage
*.md
```

Rebuild. Compare the "transferring context" line and the final size.

**Note the security angle:** without this, a stray `.env` gets baked into a layer. Anyone who
pulls the image can read it with `docker history`. Deleting it in a later `RUN` does **not**
remove it — layers are immutable and additive.

### Task 4: `COPY` vs `ADD`

You used `ADD`. Find out what else `ADD` does that `COPY` does not — it auto-extracts tar
archives and can fetch URLs. Both are surprising behaviours you did not ask for.

Switch to `COPY`. Rule: **always `COPY` unless you specifically need `ADD`'s extraction.**

### Task 5: Multi-stage — and what it's actually for

Your image ships the TypeScript compiler, every `devDependency`, and your source `.ts` files.
None of it runs in production. It is dead weight and extra attack surface.

Split build from runtime:

```dockerfile
# ---- build stage ----
FROM node:20-slim AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- runtime stage ----
FROM node:20-slim
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /usr/src/app/dist ./dist
CMD ["node", "dist/main.js"]
```

The key line is `COPY --from=builder`. Only the named artefacts cross the boundary; **everything
else in the build stage is discarded.**

Note the base image also moved from `node:18` to `node:20`. Your CI pins Node 20.10.0 — your
Dockerfile was building on 18. **Your CI and your image were testing different runtimes.** That
is problem number three, and the kind of thing that produces a bug reproducible only in prod.

### Task 6: Stop running as root

By default the process runs as UID 0. If someone escapes your app, they are root in the
container — and with a kernel bug or a careless mount, potentially beyond it.

You have already internalised this principle: your `healthcheck` Ansible role deliberately uses a
dedicated system user with a `nologin` shell. Same reasoning, different layer of the stack.

```dockerfile
COPY --from=builder --chown=node:node /usr/src/app/dist ./dist
USER node
CMD ["node", "dist/main.js"]
```

The `node` image already ships an unprivileged `node` user. Verify:

```bash
docker run --rm notely:optimised whoami   # should NOT say root
```

### Task 7: Add a healthcheck

The repo has a readiness endpoint (`src/api/readiness.ts`). Wire it up:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:8080/api/readiness').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
```

This is the same idea as the Compose healthchecks you already use — and the same idea as your
`lab-healthcheck` timer. Orchestrators use it to decide whether to route traffic to a container.
It is what Kubernetes readiness probes are built on, so you will meet it again in Module 7.

### Task 8: Measure the win

```bash
docker build -t notely:optimised .
docker images | grep notely
```

Fill this in — it goes in the README:

| | Baseline | Optimised | Change |
| --- | --- | --- | --- |
| Image size | | | |
| Cold build | | | |
| Rebuild after source change | | | |
| Runs as root | yes | no | |

### Task 9: Volumes vs bind mounts

This was the other identified gap. Do not read about it — prove it to yourself.

```bash
# Named volume
docker volume create testdata
docker run --rm -v testdata:/data alpine sh -c "echo 'from volume' > /data/file.txt"
docker run --rm -v testdata:/data alpine cat /data/file.txt

# Bind mount
mkdir -p /tmp/binddemo
docker run --rm -v /tmp/binddemo:/data alpine sh -c "echo 'from bind' > /data/file.txt"
cat /tmp/binddemo/file.txt      # visible on the host

# Now the question that matters
docker run --rm -v testdata:/data alpine ls -la /data
docker volume inspect testdata  # where does this actually live on disk?
```

Answer these in writing:

1. Where does a **named volume** physically live, and who manages it?
2. Which of the two would you use for a Postgres data directory, and why?
3. Which would you use to live-reload source code during development, and why?
4. In your Marketplace Compose file you wrote both `- .:/app` and `- /app/node_modules`.
   **What does that second, path-only entry actually do, and why is it needed?**
   *(This is a genuinely good interview question and you wrote the answer months ago.)*
5. What happens to a named volume when you `docker compose down`? What about
   `docker compose down -v`?

### Task 10: Scan the image

```bash
# Arch
sudo pacman -S trivy   # or: docker run --rm aquasec/trivy image notely:optimised

trivy image notely:baseline
trivy image notely:optimised
```

Compare CVE counts between the two. A smaller image with fewer packages has less to exploit —
that is the security argument for multi-stage, quantified.

### Task 11: The real test — containerise something from scratch

`complex-sportiv` has **no** Dockerfile. Containerise the backend yourself, from nothing, using
everything above. No copying from your other repos.

Requirements:

- Multi-stage build
- Correct layer ordering for cache efficiency
- `.dockerignore`
- Non-root user
- `HEALTHCHECK`
- A `docker-compose.yml` bringing up the API **and** PostgreSQL, with the database health-gated
  via `depends_on: condition: service_healthy`
- The app reads its DB connection from the environment, not a hard-coded string

Then prove it works end to end:

```bash
docker compose up -d
docker compose ps          # both healthy
curl localhost:PORT/...    # app responds
docker compose down -v
```

---

## The five problems

Come back and name them without scrolling. For reference, they were:

1. `ADD . .` before `npm ci` — destroys layer caching on every source change
2. No `.dockerignore` — bloated context, and a real risk of baking `.env` into a layer
3. `node:18` in the image vs Node 20.10.0 in CI — testing a different runtime than you ship
4. Single stage — compiler, devDependencies and source all shipped to production
5. Runs as root, and has no healthcheck

---

## What You're Learning

- **Layer caching** — how it works, and how instruction order controls it
- **Build context** — what gets sent to the daemon, and why `.dockerignore` is a security control
- **Multi-stage builds** — the rationale, not just the syntax
- **Least privilege in containers** — the same principle as your `healthcheck` system user
- **Volume semantics** — named volumes vs bind mounts, and lifecycle
- **Image security** — surface area as a function of image contents, measured with `trivy`

This closes a claim you cannot currently make honestly. In `Marketplace-BE` you wrote the
*original* Docker setup; the multi-stage production Dockerfile was someone else's work. After
Task 11 you will have written one yourself, on your own code, with measurements.

---

## Verification

1. `docker build` twice with a source change between — `npm ci` layer is **cached** the second time
2. Optimised image is **materially smaller** than baseline, with the numbers written down
3. `docker run --rm <image> whoami` does not print `root`
4. `docker compose ps` shows `complex-sportiv` API and DB both **healthy**
5. You can answer all five volume questions in Task 9 without looking them up
6. You can name the five problems in the original Dockerfile from memory

## Deliverables

1. The before/after table from Task 8, with real numbers
2. Optimised Dockerfile + `.dockerignore` pushed to `learn-cicd-typescript-starter`
3. New Dockerfile + `docker-compose.yml` pushed to `complex-sportiv`
4. Your written answers to the five volume questions
5. `trivy` output for both images

---

## Next

**Module 7: Kubernetes.** You assessed yourself as a total beginner there, so it starts with
roughly a week of concepts — pods, deployments, services, ingress, and the reconciliation-loop
model — before any cluster work. Then k3s across `web01`, `storage01` and `monitor01`, deployed
with an Ansible role, with the container you built here as the workload.
