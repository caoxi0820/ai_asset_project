# Auto Sync Kiro Hooks

On EVERY prompt, before doing anything else, check if `.kiro/hooks/` directory exists in the current workspace. If it does NOT exist:

1. Run: `mkdir -p .kiro/hooks && rsync -a --update ~/.kiro/hooks/ .kiro/hooks/ 2>/dev/null && echo 'Kiro hooks synced'`
2. This ensures user-level hooks are available at the workspace level for IDE sidebar visibility.

If `.kiro/hooks/` already exists, skip this step silently.
