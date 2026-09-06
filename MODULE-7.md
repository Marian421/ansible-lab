# Module 7: Kubernetes on k3s — reconciliation, not deployment

## Scenario

You have a container image from Module 6 and a systemd unit that runs it. Someone asks:

> "The host it runs on just died. What happens? And if I want three copies of it, where do they
> go, and how does traffic find them?"

Right now the answer is "nothing happens, and I go fix it by hand." Kubernetes exists to make
that answer automatic. This module is about understanding the mechanism well enough to trust it —
and to debug it when it does the wrong thing.

---

## Why this module exists

You self-assessed as a total beginner here, and that is accurate: this is the only module on the
path where you start from nothing. So it is also the only one that spends a full week on
concepts before touching a cluster. That is deliberate. Kubernetes punishes people who learn the
commands before the model — they can run `kubectl apply` and cannot explain why a pod is stuck in
`Pending`.

The good news is that you already hold most of the underlying ideas. They are just distributed
across the previous six modules:

| You already understand | Kubernetes calls it |
|------------------------|---------------------|
| Ansible declaring desired state | the same idea, running continuously |
| systemd restarting a failed service | the kubelet, restarting a failed container |
| Compose service names resolving (`postgres:5432`) | Service DNS |
| `HEALTHCHECK` from Module 6 | liveness and readiness probes |
| Prometheus generating targets from inventory groups | service discovery via label selectors |
| UFW rules restricted by source | NetworkPolicy |
| NFS exports with consistent UIDs | PersistentVolumes and `fsGroup` |
| `promtool check rules` before deploying | admission control and `--dry-run=server` |

**The one genuinely new idea** is the reconciliation loop. Everything else is a renaming.

---

## The idea worth getting right

When you run `ansible-playbook`, Ansible compares desired state to actual state, fixes the
difference, and **exits**. If someone stops a service ten minutes later, nothing notices until
you run the playbook again.

Kubernetes never exits. A controller watches the desired state, compares it to reality, and acts
— continuously, forever, in a loop. You do not tell it to start a container. You record that
three replicas should exist, and a controller spends the rest of its life making that true.

This is why Kubernetes feels strange at first: **you cannot give it an instruction, only a fact.**
`kubectl delete pod` does not delete a pod in any lasting sense — it deletes one, the Deployment
controller notices it now has two of three replicas, and creates another. People lose hours to
this before the model clicks.

Every confusing Kubernetes behaviour reduces to: *which controller is reconciling what, and what
does it currently believe the desired state to be?*

---

## Topology

```
              laptop
                 │  SSH via bastion
   ┌─────────────┼──────────────────────────────┐
   │             │                              │
   ▼             ▼                              ▼
bastion       web01                         storage01
  .10         .20                             .30
              k3s SERVER                      k3s AGENT
              control plane                   workload
              + workload                      + NFS server (PVCs)

                        monitor01  .40
                        OUTSIDE the cluster
                        Prometheus / Alertmanager / Grafana / Loki
                        scrapes the cluster from the outside
```

Two nodes, not three. `monitor01` holds 1.5 GB of its 2 GB ceiling running the observability
stack, and the host has no spare RAM to raise it. It also should not be in the cluster: a
monitoring plane that dies with the thing it monitors is worthless precisely when you need it.
That constraint produced the correct architecture, which is a common way for correct
architectures to arrive.

---

## Tasks

### Task 7.1 — Concepts, with no cluster running (~8h)

No installation this week. Work through the model until you can answer the questions below
without looking.

**The objects, in dependency order.** Learn them in this order, because each exists to solve a
problem created by the previous one:

1. **Pod** — one or more containers scheduled together, sharing a network namespace and able to
   share volumes. The unit of scheduling. Pods are mortal and get replaced, never repaired.
2. **ReplicaSet** — keeps *N* identical pods running. Solves "the pod died."
3. **Deployment** — manages ReplicaSets to perform rolling updates and rollbacks. Solves
   "I need to change the image without downtime." You will almost never create a ReplicaSet
   directly; you create Deployments, and they create ReplicaSets.
4. **Service** — a stable name and virtual IP in front of a changing set of pods, selected by
   label. Solves "pods keep being replaced and their IPs keep changing."
5. **Ingress** — HTTP routing from outside the cluster to Services, by hostname and path. Solves
   "I do not want a separate external port per service."
6. **ConfigMap / Secret** — configuration and credentials, injected as environment variables or
   files. Solves "configuration is baked into the image."
7. **PersistentVolumeClaim** — a request for storage that outlives the pod. Solves "pods are
   mortal but the database is not."

**Labels and selectors deserve special attention.** They are how everything is wired: a Service
does not point at pods, it declares a label selector and matches whatever currently carries those
labels. This is the same mechanism as your Prometheus config generating targets from the
`monitored` inventory group — membership by attribute, not by list. Nearly every "my Service
returns nothing" problem is a selector that matches no pods.

**Answer in writing before moving on:**

1. You `kubectl delete pod` a pod belonging to a Deployment. What happens, and why?
2. A pod is stuck in `Pending`. Name three distinct causes.
3. What is the difference between a liveness probe failing and a readiness probe failing?
4. Why does a Service need a selector rather than a list of pod IPs?
5. Your Deployment says `replicas: 3` and only two pods are running, with no error. Where do you
   look first?
6. What is the difference between a Deployment and a StatefulSet, and which does a database want?

**Recommended:** the official concepts documentation, read in the object order above. Skip the
tutorials for now — they teach commands, and commands without the model are the failure you are
trying to avoid.

### Task 7.2 — Install k3s by hand on `web01`, then take it apart (~6h)

Install manually **first**, even though task 7.3 automates it. Automating something you have
never done by hand produces a role you cannot debug.

```bash
ssh web01
curl -sfL https://get.k3s.io | sh -
```

Now investigate what that script actually did. This is the valuable half of the task:

```bash
systemctl status k3s
systemctl cat k3s                    # what flags is it running with?
ls /etc/rancher/k3s/                 # config and kubeconfig
ls /var/lib/rancher/k3s/             # data directory, embedded database
sudo k3s crictl ps                   # containers, without Docker
sudo ss -tlnp | grep -E '6443|10250'
```

**Understand before continuing:**

- k3s is an ordinary **systemd service**. Everything you know about `systemctl`, unit files and
  `journalctl` applies unchanged. This is why it is automatable with the skills you already have.
- It bundles containerd, not Docker. Your images still work — the image format is a standard,
  the runtime is an implementation detail. `docker` commands do not work on the node; `crictl`
  does.
- The control plane components run **as containers, on the cluster they control**.
- The embedded datastore holds all cluster state. Lose `/var/lib/rancher/k3s/server/db` and you
  have lost the cluster.

Get `kubectl` working from your laptop rather than typing everything over SSH:

```bash
# on web01
sudo cat /etc/rancher/k3s/k3s.yaml
# on the laptop: copy to ~/.kube/config, replace 127.0.0.1 with the web01 address
kubectl get nodes
kubectl get pods -A
```

Then run one thing, purely to see the loop work:

```bash
kubectl create deployment nginx --image=nginx
kubectl get pods -w        # in one terminal
kubectl delete pod <name>  # in another — watch the replacement appear
```

That replacement is the entire module in one observation.

### Task 7.3 — Automate it, and open the firewall properly (~12h)

Now write it as Ansible, the way every other service in this lab is deployed. Two roles:

- `roles/k3s_server` — installs k3s on `web01`, captures the node token
- `roles/k3s_agent` — installs the agent on `storage01`, joins it to the server

Points to get right:

- **The node token** lives at `/var/lib/rancher/k3s/server/node-token` on the server. Read it with
  `ansible.builtin.slurp` and pass it to the agent via `hostvars` — the same cross-host fact
  pattern the `firewall` role already uses. The `--limit` warning in the README applies here for
  exactly the same reason.
- **Idempotency.** `curl | sh` is not idempotent. Guard the install with a `creates:` argument or
  a `stat` check, and confirm a second run reports zero changes. This is the part `ansible-lint`
  will not catch for you.
- **Disable what you do not need.** `--disable traefik --disable servicelb` if you intend to
  install your own ingress controller in 7.6; leave them enabled if you do not. Decide
  deliberately and write down why — on 2 GB nodes this matters.
- **Firewall rules.** Extend `roles/firewall` rather than opening ports by hand:

  | Port | Direction | Purpose |
  |------|-----------|---------|
  | 6443/tcp | laptop + agents → server | Kubernetes API |
  | 8472/udp | node ↔ node | Flannel VXLAN overlay |
  | 10250/tcp | server → agents, `monitor01` → all | kubelet API and metrics |

  Keep every rule source-restricted, consistent with the rest of the lab. Do not weaken the
  default-deny policy — a cluster that only works with the firewall off is a cluster you do not
  understand yet.

**Verification:**

```bash
ansible-playbook first-playbook.yml            # first run: changes
ansible-playbook first-playbook.yml            # second run: zero changed
kubectl get nodes                              # 2 Ready
ansible-lint                                   # still 5/5
```

Then the real test: `k3s-uninstall.sh` on both nodes, re-run the playbook, and get the cluster
back unattended. If that works, the role is finished.

### Task 7.4 — Deploy your own image (~8h)

Use the image you built in Module 6, not `nginx`.

Write real manifests in `k8s/` — do not use `kubectl create` and dump the generated YAML, which
produces noise you cannot read later.

```
k8s/
├── deployment.yaml
├── service.yaml
├── ingress.yaml
├── configmap.yaml
└── pvc.yaml
```

The Deployment must include:

- `replicas: 2`
- **resource requests and limits.** Not optional on 2 GB nodes. A pod with no request will be
  scheduled anywhere and can starve the node; a pod with a memory limit that is exceeded is
  killed. Set them, then deliberately set a limit too low and watch the `OOMKilled` status so you
  recognise it later.
- **liveness and readiness probes** pointing at the readiness endpoint you wired up in Module 6.
  This is where task 6.7 pays off.
- an explicit image tag. Never `:latest` — you cannot roll back to a tag that moves.

Then exercise it:

```bash
kubectl apply -f k8s/
kubectl get pods -o wide            # which node did each land on, and why?
kubectl describe pod <name>         # read the Events section — this is where answers live
kubectl logs <name>
kubectl scale deployment/<name> --replicas=4
kubectl set image deployment/<name> app=<image>:v2   # watch the rolling update
kubectl rollout undo deployment/<name>
```

`kubectl describe` is the single most useful command in Kubernetes. The `Events` section at the
bottom explains almost every failure. Read it before searching the web.

### Task 7.5 — Configuration and secrets (~5h)

Move configuration out of the image:

```bash
kubectl create configmap app-config --from-literal=LOG_LEVEL=debug
kubectl create secret generic app-secret --from-literal=DB_PASSWORD=...
```

Consume both as environment variables in the Deployment, and confirm the app reads them.

**Then look at what a Secret actually is:**

```bash
kubectl get secret app-secret -o yaml
echo '<the value>' | base64 -d
```

Base64 is not encryption. A Secret is stored unencrypted in the cluster datastore by default and
is readable by anyone with the right permissions. It is a *namespacing and access-control*
mechanism, not a vault. This is exactly why Module 10 covers SOPS and Key Vault — and why a
Secret must never be committed to git. Write down the distinction; it is a common misconception
worth not holding.

### Task 7.6 — Ingress (~6h)

Expose the app by hostname rather than by port number.

- If you kept Traefik, use it. If you disabled it, install ingress-nginx.
- Create an Ingress routing a hostname to your Service.
- Add the hostname to your laptop's `/etc/hosts`, pointing at `web01`.
- Reach it from a browser.

**Understand the layering**, because this is a frequent point of confusion — an Ingress is not a
load balancer. It is a *configuration object*. An ingress controller (a pod, running in the
cluster, watching the API) reads Ingress objects and reconfigures itself accordingly. Another
reconciliation loop. Without a controller installed, an Ingress does nothing at all and reports
no error.

Also compare the Service types and be able to say when each applies: `ClusterIP` (internal only),
`NodePort` (a fixed high port on every node), `LoadBalancer` (asks the infrastructure for an
external address — in a cloud this creates a real one, on bare metal it needs something like
k3s's servicelb or MetalLB to mean anything).

### Task 7.7 — Persistent storage on your own NFS server (~8h)

The nicest task in the module: `storage01` is already an NFS server you built and configured.
Now back cluster storage with it.

- Install the NFS subdirectory external provisioner, pointed at an export on `storage01`.
- Create a PVC, mount it in a pod, write a file.
- Delete the pod, let it be recreated, and confirm the file is still there.
- Look at the directory on `storage01` directly — see the volume as a real path on a real disk.

**Understand:**

- **PV vs PVC vs StorageClass** — a PVC is a *request* ("10Gi, ReadWriteMany"), a PV is the actual
  volume, and a StorageClass is what creates PVs on demand so nobody has to pre-create them.
  Another controller, another loop.
- **Access modes** — `ReadWriteOnce` versus `ReadWriteMany`, and why NFS can offer the latter
  while a cloud block device usually cannot.
- **UID/GID again.** Files written into an NFS-backed volume are owned by the container's user.
  This is the identical problem you solved in the `identity` role with fixed UIDs across hosts,
  reappearing one layer up. `fsGroup` in a pod security context is the Kubernetes answer.
- **Reclaim policy** — what happens to the data when the PVC is deleted. Get this wrong on
  something that matters and the data is gone.

### Task 7.8 — Wire it into the monitoring you already have (~8h)

Do **not** install kube-prometheus-stack. You already run Prometheus, Alertmanager, Grafana and
Loki on `monitor01`, deployed with roles you wrote. Extend them.

- Install `kube-state-metrics` in the cluster and expose it.
- Add a scrape target to your existing Prometheus template for kube-state-metrics and for the
  kubelet's cAdvisor metrics on 10250.
- Ship pod logs to the Loki instance you already run.
- Build or import a Grafana dashboard for cluster state.
- Add an alert rule — for example, a pod restarting repeatedly — to the Alertmanager setup that
  already works.

This is the task that turns seven modules into one coherent system rather than seven exercises.
It is also the harder path: a Helm chart would install a parallel stack in twenty minutes and
teach you nothing about how the pieces connect.

### Task 7.9 — Break it on purpose (~5h)

Predict the outcome in writing **before** running each command. The gap between your prediction
and what happens is the actual learning.

```bash
kubectl delete pod <one of several replicas>      # how long until it is replaced?
kubectl drain storage01 --ignore-daemonsets       # where do the pods go?
kubectl uncordon storage01                        # do they come back? why not?
```

Then, less politely:

- Set a readiness probe to a path that does not exist. Does the pod stay `Running`? Does it
  receive traffic? What does the Service's endpoint list show?
- Set a memory limit of `10Mi`. Read the pod status and the events.
- Request more CPU than any node has. Why is the pod `Pending`, and where does it say so?
- Fill the PVC. What does the application do? What does Kubernetes do?
- Power off `storage01` from the host. How long before the node is `NotReady`, and what happens
  to its pods? Bring it back and watch it rejoin.

Write down every observation. This set of experiments is worth more than the rest of the module
combined, because it is the difference between having deployed something and being able to
operate it.

### Task 7.10 — Document it (~4h)

- A Kubernetes section in `README.md`: topology, what runs where, how to reach the app.
- Update `docs/architecture.md` with the cluster and the outside-in monitoring path.
- A `docs/learning-journal.md` entry in the existing format — including the things that broke and
  how you diagnosed them. The journal entries describing real failures are the most valuable
  content in this repository.
- Update `CONTEXT.md` and mark Module 7 complete in `ROADMAP.md`.

---

## Verification

1. `kubectl get nodes` shows **2 Ready** nodes
2. `k3s-uninstall.sh` on both nodes, then one playbook run, rebuilds the cluster unattended
3. A second consecutive playbook run reports **zero changed**
4. `ansible-lint` still passes at 5/5
5. The app is reachable through Ingress by hostname from the laptop
6. A file written to a PVC survives pod deletion, and is visible on `storage01` as a real path
7. Cluster metrics appear in the **pre-existing** Grafana on `monitor01`
8. UFW is still default-deny, with every new rule source-restricted
9. You can answer all six questions from task 7.1 from memory
10. You can explain what happened in each experiment in task 7.9, and why

## Deliverables

1. `roles/k3s_server` and `roles/k3s_agent`, with READMEs matching the other eleven roles
2. `k8s/` manifests — Deployment, Service, Ingress, ConfigMap, Secret, PVC
3. Firewall rules for the cluster ports, source-restricted
4. Prometheus scrape configuration and an alert rule for the cluster
5. Written answers to the task 7.1 questions and the task 7.9 predictions-versus-outcomes
6. Journal entry and updated architecture documentation

---

## Next

**Module 8: Terraform on Azure.** Same architecture as this lab — network, firewall rules, shared
storage, a container — declared in HCL against a public cloud instead of Ansible against KVM.
New repository: `azure-terraform-lab`. First task is a budget alert, before a single resource
exists.
