#!/bin/bash

# Check if we're inside a tmux session
if [ -n "$TMUX" ]; then
    echo "Script is running inside an existing tmux session. Killing current session and restarting the script."
    # Get the current tmux session name
    CURRENT_SESSION=$(tmux display-message -p '#S')

    # Kill the current session
    tmux kill-session -t $CURRENT_SESSION

    # Re-run the script from the beginning (without being inside tmux)
    exec $0
    exit 0
fi

# Variables for session names
SESH_APP='beb-app'
SESH_BACKEND='beb-server'
APP_DIR="$HOME/Documents/bebsapati/bebsapati-app"
BACKEND_DIR="$HOME/Documents/bebsapati/bebsapati-backend/"

# Create the app session if it doesn't exist
tmux has-session -t $SESH_APP 2>/dev/null
if [ $? != 0 ]; then
    # app session
    tmux new-session -d -s $SESH_APP -n 'app' -c "$APP_DIR"
    tmux send-keys -t $SESH_APP:app "nvim" C-m

    # app terminal
    tmux new-window -t $SESH_APP -n "appTerm" -c "$APP_DIR"
    tmux split-window -t "$SESH_APP":appTerm -h -c "$APP_DIR"


	# select 1st teminal pane, focus nvim window
	tmux select-pane -t "$SESH_APP":appTerm.1
    tmux select-window -t $SESH_APP:app
fi

# Create the backend session if it doesn't exist
tmux has-session -t $SESH_BACKEND 2>/dev/null
if [ $? != 0 ]; then
    # backend session
    tmux new-session -d -s $SESH_BACKEND -n "backend" -c "$BACKEND_DIR"
    tmux send-keys -t $SESH_BACKEND:backend "nvim" C-m

    # backend terminal
    tmux new-window -t $SESH_BACKEND -n "backendTerm" -c "$BACKEND_DIR"
    tmux send-keys -t $SESH_BACKEND:backendTerm "bun dev" C-m
    tmux split-window -t "$SESH_BACKEND":backendTerm -h -c "$BACKEND_DIR"
	tmux send-keys -t "$SESH_BACKEND:backendTerm.1" "bun dev" C-m

	# select 2nd pane on terminal, focus nvim window
	tmux select-pane -t "$SESH_BACKEND":backendTerm.2
    tmux select-window -t $SESH_BACKEND:backend

fi

# Attach to the app session after setup
tmux attach-session -t $SESH_APP
