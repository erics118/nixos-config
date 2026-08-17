#!/usr/bin/env bash
# one-shot LLM query via the OpenRouter API, no agent harness or repo context

set -euo pipefail

KEY_FILE=/run/secrets/api/openrouter

OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
if [[ -z $OPENROUTER_API_KEY && -r $KEY_FILE ]]; then
  OPENROUTER_API_KEY=$(<"$KEY_FILE")
fi
if [[ -z $OPENROUTER_API_KEY ]]; then
  printf >&2 'ask: no api key. export OPENROUTER_API_KEY or provision %s\n' "$KEY_FILE"
  exit 1
fi

MODEL="openai/gpt-5.4-nano"
SMART_MODEL="~anthropic/claude-sonnet-latest"
SYSTEM_PROMPT=""
PROMPT=""
STREAMING=false
NO_SYSTEM=false
PROVIDER_ORDER=""
SHOW_METADATA=false

DEFAULT_PROMPT="You are a direct answer engine. Output ONLY the requested information.

For commands: Output executable syntax only. No explanations, no comments.
For questions: Output the answer only. No context, no elaboration.

Rules:
- If asked for a command, provide ONLY the command
- If asked a question, provide ONLY the answer
- Never include markdown formatting or code blocks
- Never add explanatory text before or after
- Assume output will be piped or executed directly
- For multi-step commands, use && or ; to chain them
- Make commands robust and handle edge cases silently
- If the request is invalid, nicely tell the user"

show_help() {
  cat <<EOF
ask - Query AI models via OpenRouter API

Usage: ask [OPTIONS] [PROMPT]

Options:
  -s          Use a smarter, slower model when the default gets it wrong
  -m MODEL    Use a specific model
  -r          Disable system prompt (raw model behavior)
  --stream    Enable streaming output
  --system    Set system prompt for the conversation
  --metadata  Show metadata
  --provider  Comma-separated list of providers for routing
  -h, --help  Show this help message

Examples:
  ask "Write a hello world in Python"
  ask -s "Explain quantum computing"
  ask -m google/gemini-3.6-flash "What is 2+2?"
  echo "Fix this code" | ask
  ask --system "You are a pirate" "Tell me about sailing"

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help) show_help ;;
  -s)
    MODEL="$SMART_MODEL"
    shift
    ;;
  -m)
    MODEL="${2:?Error: -m requires a model name}"
    shift 2
    ;;
  -r)
    NO_SYSTEM=true
    shift
    ;;
  --stream)
    STREAMING=true
    shift
    ;;
  --metadata)
    SHOW_METADATA=true
    shift
    ;;
  --system)
    SYSTEM_PROMPT="${2:?Error: --system requires a prompt}"
    shift 2
    ;;
  --provider)
    PROVIDER_ORDER="${2:?Error: --provider requires providers}"
    shift 2
    ;;
  *)
    PROMPT="$*"
    break
    ;;
  esac
done

if [[ -z $PROMPT ]]; then
  if [[ -t 0 ]]; then
    echo "Error: No prompt provided. Use 'ask -h' for help." >&2
    exit 1
  fi
  PROMPT=$(cat)
fi

if [[ $NO_SYSTEM == false ]] && [[ -z $SYSTEM_PROMPT ]]; then
  SYSTEM_PROMPT="$DEFAULT_PROMPT"
fi

if [[ -n $SYSTEM_PROMPT ]]; then
  MESSAGES=$(jq -n --arg sys "$SYSTEM_PROMPT" --arg u "$PROMPT" \
    '[{"role":"system","content":$sys},{"role":"user","content":$u}]')
else
  MESSAGES=$(jq -n --arg u "$PROMPT" \
    '[{"role":"user","content":$u}]')
fi

START_TIME=$(date +%s.%N)

PROVIDER_JSON=""
if [[ -n $PROVIDER_ORDER ]]; then
  IFS=',' read -r -a _providers <<<"$PROVIDER_ORDER"
  if [[ ${#_providers[@]} -gt 0 ]]; then
    PROVIDER_JSON=$(jq -n --args '$ARGS.positional' "${_providers[@]}")
  fi
fi

JSON_PAYLOAD=$(
  jq -n \
    --arg model "$MODEL" \
    --argjson messages "$MESSAGES" \
    --argjson stream "$STREAMING" \
    '{model: $model, messages: $messages, stream: $stream}'
)

if [[ -n $PROVIDER_JSON ]]; then
  JSON_PAYLOAD=$(printf '%s' "$JSON_PAYLOAD" | jq --argjson provider_order "$PROVIDER_JSON" '. + {provider: {order: $provider_order}}')
fi

API_URL="https://openrouter.ai/api/v1/chat/completions"

elapsed_since_start() {
  printf '%.2f' "$(echo "$(date +%s.%N) - $START_TIME" | bc)"
}

if [[ $STREAMING == true ]]; then
  curl -sS -N --fail-with-body "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -d "$JSON_PAYLOAD" | while IFS= read -r line; do
    if [[ $line == data:* ]]; then
      json="${line#data: }"
      if [[ -z $json ]] || [[ $json == "[DONE]" ]]; then
        continue
      fi
      content=$(jq -r '.choices[0].delta.content // ""' <<<"$json" 2>/dev/null)
      [[ -n $content ]] && printf '%s' "$content"
    fi
  done
  echo

  if [[ $SHOW_METADATA == true ]]; then
    ELAPSED=$(elapsed_since_start)
    echo
    echo "[$MODEL - ${ELAPSED}s]" >&2
  fi
else
  status=0
  response="$(curl -sS --fail-with-body "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -d "$JSON_PAYLOAD")" || status=$?

  if [[ $status -ne 0 ]]; then
    echo "Error: $(printf '%s' "$response" | jq -r '.error.message // .error // "Unknown error"')" >&2
    exit 1
  fi

  printf '%s' "$response" | jq -r '.choices[0].message.content // "No response received"'

  if [[ $SHOW_METADATA == true ]]; then
    ELAPSED=$(elapsed_since_start)
    TOKENS=$(printf '%s' "$response" | jq -r '.usage.completion_tokens // 0')
    PROVIDER=$(printf '%s' "$response" | jq -r '.provider // "Unknown"')
    TPS=$(echo "scale=1; $TOKENS / $ELAPSED" | bc 2>/dev/null || echo "0.0")

    echo
    echo "[$MODEL via $PROVIDER - ${ELAPSED}s - ${TPS} tok/s]" >&2
  fi
fi
