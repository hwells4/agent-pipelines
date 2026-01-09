# tmux Command Reference

<session_management>
```bash
# Create detached session
tmux new-session -d -s NAME -c /path './command'

# Check if session exists
tmux has-session -t NAME 2>/dev/null && echo "exists"

# List all sessions
tmux list-sessions

# Kill session
tmux kill-session -t NAME

# Kill all loop sessions
tmux list-sessions -F "#{session_name}" | grep "^loop-" | xargs -I {} tmux kill-session -t {}
```
</session_management>

<attach_detach>
```bash
# Attach to session
tmux attach -t NAME

# Detach (from inside): Ctrl+b, then d

# Switch sessions (from inside):
# Ctrl+b, s    - list sessions
# Ctrl+b, (    - previous session
# Ctrl+b, )    - next session
```
</attach_detach>

<output_capture>
```bash
# Capture visible pane
tmux capture-pane -t NAME -p

# Capture with scrollback
tmux capture-pane -t NAME -p -S -1000

# Capture to file
tmux capture-pane -t NAME -p > output.txt

# Tail recent output
tmux capture-pane -t NAME -p | tail -50
```
</output_capture>

<session_info>
```bash
# Session creation time (unix timestamp)
tmux list-sessions -F "#{session_name} #{session_created}"

# Check if session is attached
tmux list-sessions -F "#{session_name} #{session_attached}"

# Get session working directory
tmux display -t NAME -p "#{pane_current_path}"
```
</session_info>

<scripting>
```bash
# Send keys to session
tmux send-keys -t NAME "command" Enter

# Send Ctrl+C to stop
tmux send-keys -t NAME C-c
```
</scripting>
