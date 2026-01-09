# Workflow: Attach to a Session

<process>

## Step 1: Verify Session Exists

```bash
tmux has-session -t loop-NAME 2>/dev/null || echo "Session not found"
```

## Step 2: Warn About Terminal Takeover

**Important:** Attaching takes over your terminal. You won't be able to run other commands until you detach.

Tell the user:
```
Attaching to loop-NAME will take over this terminal.

To detach (return to normal): Press Ctrl+b, then d

Ready? Run: tmux attach -t loop-NAME
```

## Step 3: Attach

```bash
tmux attach -t loop-NAME
```

## Step 4: After Detaching

When user detaches (Ctrl+b, d), session continues running in background.

Remind them:
```
Detached from loop-NAME. Session continues running.

Check later with: tmux capture-pane -t loop-NAME -p | tail -20
```

</process>

<detach_instructions>
**To detach from inside tmux:**
1. Press `Ctrl+b` (release both keys)
2. Press `d`

Session keeps running. You return to normal terminal.
</detach_instructions>

<success_criteria>
- [ ] User warned about terminal takeover
- [ ] User knows how to detach
- [ ] Session attached successfully
</success_criteria>
