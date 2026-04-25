# docs/pr-workflow.md

## PR Workflow

1. Lock upstream revision used for translation.
2. Implement against inventory items in `plans/inventory/`.
3. Update inventory statuses as work advances.
4. Run quality gates: `make format && make lint && make test`.
5. Open PR with:
   - Summary of translated modules
   - Upstream revision pinned
   - Reference to relevant inventory items
