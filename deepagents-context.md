## DeepAgents harness

The `deepagents` package is installed and pre-wired to a local Docker Model
Runner, so you can build a planning agent with a virtual filesystem and
sub-agents without any cloud credentials.

- Build an agent with `create_deep_agent(model=..., system_prompt=...)`. The
  model is an OpenAI-compatible client (`ChatOpenAI`) pointed at the Model
  Runner via `OPENAI_BASE_URL` / `OPENAI_API_KEY` — no Anthropic or OpenAI key
  is needed or present.
- A runnable starting point is at `~/deepagents_quickstart.py`. Run it with
  `python3 ~/deepagents_quickstart.py`.
- `DEEPAGENTS_MODEL` selects the Model Runner model (default `ai/qwen3`). It
  must support tool calling, and must already be pulled on the host.
