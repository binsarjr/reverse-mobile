# Reverse Engineering - Docker-First Approach

## Quick Start

1. **Docker Readiness**: Run `./docker-setup.sh` at session start
2. **Read SKILLS.md**: Contains Docker-first reverse engineering instructions
3. **Read AGENT_TEAMS.md**: Contains 5-role team configuration

## Project Structure

```
reverse-mobile/
├── SKILLS.md           # Docker-first reverse engineering skill
├── AGENT_TEAMS.md      # Agent team roles & workflow
├── docker-setup.sh     # Docker readiness script
├── README.md           # Project README
├── findings/           # Output directory for analysis results
└── .claude/           # Claude configuration
```

## Docker Images Used

| Image | Purpose |
|-------|---------|
| `cryptax/android-re:latest` | APK analysis (jadx, apktool, androguard) |
| `trufflesecurity/trufflehog:latest` | Secret scanning |
| `zricethezav/gitleaks:latest` | Secret scanning |
| `node:20-alpine` | Web bundle beautification |

## Agent Team Roles

| Agent | Responsibility |
|-------|---------------|
| Orchestrator | Workflow coordination |
| Extractor | Docker & file extraction |
| Analyzer | Static analysis |
| Deobfuscator | Decoding & deception analysis |
| Reporter | Report generation |

## Workflow

1. Run `docker-setup.sh` to prepare environment
2. Identify target type (APK/IPA/Web)
3. Extract via Docker: `SEQUENTIAL`
4. Analyze via Docker: `PARALLEL`
5. Deobfuscate: `PARALLEL`
6. Report: Aggregate findings

## Output

Analysis results go to `findings/[app-name]-[YYYY-MM-DD]/`

## GitHub Raw URLs

For AI agents to read skill files directly:

```
https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/SKILLS.md
https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/AGENT_TEAMS.md
https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/docker-setup.sh
```
