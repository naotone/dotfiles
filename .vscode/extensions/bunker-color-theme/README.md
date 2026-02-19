# Bunker Color Theme

Minimal dark theme with muted neutrals and bright accent colors that keep focus on code while preserving clarity in the workbench.

## Features
- Modern workbench coverage: command center, sticky scroll, minimap, status bar states, and quick input.
- Semantic token colors tuned to mirror the classic TextMate scopes for consistent highlighting.
- Extended terminal and SCM decorations so new VS Code UI avoids default fallbacks.

## Installation
- Open the Extensions view in VS Code and search for `Bunker Color Theme`.
- Or package locally with `pnpm run package` and install the generated `.vsix`.

## Development
```bash
pnpm install
pnpm run lint
pnpm run package
```
- `pnpm run lint`: Validates the JSON theme files with ESLint + jsonc rules.
- `pnpm run package`: Creates a VSIX via `vsce`; publish with `pnpm run publish` after signing in.

## Contributing
- Palette anchors: backgrounds `#121314`~`#1A1C1F`, foreground `#DBDBDB`, accents `#FF5A5F`, `#43C0D6`, `#A9DEAC`, `#F5CF5D`.
- Keep semantic token colors in sync with TextMate scopes when adjusting hues.
- Run `pnpm run lint` and test the theme on the latest stable VS Code before releasing.
