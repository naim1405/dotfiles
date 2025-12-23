#!/bin/bash

DRY=false

while IFS= read -r line; do
	if [[ DRY == true ]]; then
		echo "[DRY} yay -S --noconfirm --needed --answerclean None --answerdiff None ${line}"
	else
		yay -S --noconfirm --needed --answerclean None --answerdiff None ${line}
	fi

done < apps.lst
