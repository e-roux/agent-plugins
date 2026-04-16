---
name: banner
description: "Box-drawing banner generator. Use when creating or updating a Makefile help target header. Runs a local bash script — no binary required."
---

# Banner Skill

Generates a 3-row box-drawing ASCII art banner from text (letters A–Z and space).

## Usage

```bash
bash skills/banner/banner.sh "TEXT"
```

Run from the repository root. The script reads `skills/banner/letters.json` automatically.

## Example

```bash
bash skills/banner/banner.sh "MAKE"
```

Output (paste row-by-row into the `help` target):

```
╔╦╗╔═╗╦╔ ╔═╗
║║║╠═╣╠╩╗║╣ 
╝ ╝╝ ╝╝ ╝╚═╝
```

## Makefile integration

```makefile
help:
	printf "\033[36m"
	printf "╔╦╗╔═╗╦╔ ╔═╗\n"
	printf "║║║╠═╣╠╩╗║╣ \n"
	printf "╝ ╝╝ ╝╝ ╝╚═╝\n"
	printf "\033[0m\n"
```

## Rules

- **Input**: letters A–Z and spaces. Case-insensitive. 1–12 characters recommended for a single terminal line.
- **Output**: exactly 3 rows separated by `\n`, no trailing newline.
- **Unknown characters** silently fall back to the space glyph.
- **NEVER** hand-craft banners letter-by-letter — always call this script.
