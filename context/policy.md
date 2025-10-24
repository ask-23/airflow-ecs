# Drop this tiny file

cat > context/_policy.md <<'MD'
RULES

1) Before creating any code, each agent must read all assigned context docs.
2) Each agent must write a Context Receipt to docs/receipts/<agent>.md that:
   - Summarizes the assigned docs in 10 bullets max
   - Lists open questions
   - States the interfaces it depends on (paths, ports, env vars)
   - Includes SHA256 of each context file read
3) Reviewer blocks any work without a valid receipt.
MD
