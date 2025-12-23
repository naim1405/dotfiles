#!/bin/bash

# Define the tmux session name
SESSION_NAME="kitty"

# Check if the tmux session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

# $? checks the exit status of the last command, 0 means the session exists
if [ $? != 0 ]; then
    echo "Session $SESSION_NAME does not exist, creating a new session..."
else
    # If session exists, kill it
    echo "Session $SESSION_NAME already exists, killing it..."
    tmux kill-session -t $SESSION_NAME
fi

# Start a new tmux session in the background (detached)
tmux new-session -d -s $SESSION_NAME

# Run tmux inside Kitty
kitty --hold tmux attach -t $SESSION_NAME
