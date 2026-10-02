# docker-sbx-deepagents

A [Docker Sandbox Kit](https://github.com/docker/sandbox-kit-spec) (**v3**,
`schemaVersion: "3"`) that adds the [deepagents](https://github.com/langchain-ai/deepagents)
agent harness (planning, a virtual filesystem, sub-agents) to an agent
sandbox, pre-wired to a **local Docker Model Runner** for the LLM. No cloud
credentials, no hosted tracing.

## Architecture

```
          your host
  ┌──────────────────────────────────────────────────────────┐
  │                                                            │
  │   Docker Model Runner  ──  :12434  (OpenAI-compatible)     │
  │            ▲                                               │
  │            │  egress allowed only to                       │
  │            │  host.docker.internal:12434                   │
  │   ┌────────┴──────────────  sandbox  ──────────────────┐   │
  │   │  shell workload  +  deepagents mixin               │   │
  │   │    • deepagents + langchain-openai (pip, create)   │   │
  │   │    • OPENAI_BASE_URL / OPENAI_API_KEY pre-wired     │   │
  │   │    • ~/deepagents_quickstart.py                     │   │
  │   └─────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────┘
```

The mixin composes onto a workload. The sandbox may reach exactly one host
(the Model Runner on `:12434`) and nothing else at runtime; PyPI opens only
while the kit installs, then closes.

## Files

This is a **mixin** in companion-pair form:

| File | Role |
|---|---|
| `deepagents.yaml` | the v3 descriptor: network policy, agent context, lifecycle hooks |
| `deepagents.dockerfile` | a `FROM scratch` overlay that carries the runtime `ENV` onto the composed image |
| `deepagents-context.md` | agent guidance, staged via `agent-context@1` |

## What it does

- Installs `deepagents==0.7.21` (+ `langchain-openai`) into the composed
  workload's Python at sandbox-create time, via `lifecycle@1` install hooks,
  and re-reads the version to enforce the pin.
- Carries `OPENAI_BASE_URL` / `OPENAI_API_KEY` / `DEEPAGENTS_MODEL` as `ENV`,
  wiring the agent to the Model Runner at `host.docker.internal:12434`.
- Stages a runnable `~/deepagents_quickstart.py` (not overwritten if present).
- Phase-scoped egress: PyPI opens only during install; the running agent may
  reach only the Model Runner.
- No `credential@1`: the Model Runner `api_key` is the sentinel `"dmr"`, not a
  secret.

## Prerequisites

- The [`sbx` CLI](https://docs.docker.com/ai/sandboxes/install/) (Kits v3) and a
  running Docker daemon.
- **Docker Model Runner** enabled, serving a tool-calling model. Pull the
  default (or set `DEEPAGENTS_MODEL` to another):

  ```sh
  docker model pull ai/qwen3
  ```

- A composed base with **Python ≥ 3.11** and pip (e.g. `docker/sbx-kit-shell`).
  The kit's first install hook fails early with a clear message if the Python
  is too old.

## Use it

```sh
# Validate the descriptor (fails in a second on a bad field; builds no content):
docker buildx build . -f deepagents.yaml --output type=cacheonly

# Run it composed onto a shell workload (source form, no registry/push needed).
# Point --kit at the kit directory by path so the artifact gets a valid name:
sbx run docker/sbx-kit-shell:1.0.0 \
  --kit "$(pwd)" --name deepagents-demo /path/to/your/workspace

# Inside the sandbox:
cat /usr/share/sandbox/kit/deepagents/kit.yaml      # the published descriptor
python3 -c "import deepagents; print('deepagents', deepagents.__version__)"
python3 ~/deepagents_quickstart.py                  # talk to the Model Runner
```

## Build & verify

```sh
# Export an OCI layout and run the conformance suite (note the bare tag):
docker buildx build . -f deepagents.yaml -t deepagents:0.7.21 \
  --output type=oci,dest=/tmp/deepagents-layout,tar=false
kit-tck validate --layout /tmp/deepagents-layout 0.7.21
```

## Published image

A multi-arch (linux/amd64, linux/arm64) build is on Docker Hub:

```sh
# Run the published kit composed onto a shell workload:
sbx run docker/sbx-kit-shell:1.0.0 \
  --kit docker.io/ajeetraina777/sbx-kit-deepagents:0.7.21 --name deepagents-demo .
```

To rebuild and push your own:

```sh
docker buildx build . -f deepagents.yaml --platform linux/amd64,linux/arm64 --push \
  -t docker.io/ajeetraina777/sbx-kit-deepagents:0.7.21 \
  -t docker.io/ajeetraina777/sbx-kit-deepagents:latest
```

## Removing the kit

```sh
sbx rm -f deepagents-demo
```

## Notes for adopters

- deepagents defaults to an Anthropic model; this kit overrides that by passing
  an explicit `ChatOpenAI` instance pointed at the Model Runner, so no Anthropic
  key is needed. To use a cloud model instead, add a `credential@1` capability
  and construct the model accordingly.
- The install runs against the **composed base** at create time, so the kit
  works regardless of what Python packages the base already carries, as long
  as the Python is ≥ 3.11.
