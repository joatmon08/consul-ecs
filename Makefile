readme:
	echo "\n## Required Environment Variables\n" >> README.md
	sed -n 's/echo "set \([A-Z].*\)."*/- \1/p' entrypoint.sh >> README.md
	echo "\n## Optional Environment Variables\n" >> README.md
	sed -n 's/echo "\([A-Z].*will default to.*\)./- \1/p' entrypoint.sh >> README.md