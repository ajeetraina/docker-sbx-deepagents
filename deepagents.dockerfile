# syntax=docker/dockerfile:1
#
# deepagents is an env-carrying overlay. It installs nothing into the image: the
# deepagents wheel and its langchain dependency closure land in the *composed
# base's* system Python at create time, via the lifecycle install hooks in
# deepagents.yaml (a mixin overlay lands on an unknown base, so relocating
# site-packages here would not resolve against that base's Python).
#
# This recipe exists only to carry the runtime environment onto the composed
# image. A mixin's ENV is an additive image-config field that merges at assembly,
# so it reaches the composed image and the agent process (BASH_ENV launches the
# agent, so profile/rc files would miss it). ENV must be on the final stage.
#
# `FROM scratch` keeps the layer purely the overlay: the frontend stages the
# descriptor as the single content layer and this ENV rides in the image config.
FROM scratch

# OPENAI_* point the OpenAI-compatible client at the host's Docker Model Runner.
# The api_key is the Model Runner sentinel "dmr", not a real credential — which
# is why this kit declares no credential@1. DEEPAGENTS_MODEL names the Model
# Runner model the quickstart uses by default; override it to any pulled model
# that supports tool calling. LANGSMITH_TRACING=false keeps langchain from
# attempting hosted tracing egress, which the runtime network policy would block
# anyway. NO_PROXY is deliberately NOT set here: the shell workload already
# defines it, and a mixin setting the same variable to a different value is a
# hard composition conflict — egress to the Model Runner is enforced at the
# proxy boundary regardless of the app-level NO_PROXY.
ENV OPENAI_BASE_URL="http://host.docker.internal:12434/engines/v1" \
    OPENAI_API_KEY="dmr" \
    DEEPAGENTS_MODEL="ai/qwen3" \
    LANGSMITH_TRACING="false"
