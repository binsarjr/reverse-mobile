# Docker-First Reverse Engineering Setup

## Quick Start

### For AI Agent (Claude Code)

Tell the agent to read the raw files from this repo:

```
https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/SKILLS.md
```

Example for agent:
> "Read `https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/SKILLS.md` and use it for reverse engineering the APK in this folder. Run `./docker-setup.sh` first to prepare the Docker environment."

### Manual Setup

```bash
# Clone this repo
git clone https://github.com/{USERNAME}/{REPO}.git
cd {REPO}

# Prepare Docker environment
./docker-setup.sh

# Read the skill file
cat SKILLS.md
```

## Workflow

```
┌─────────────────────────────────────┐
│ 1. Run docker-setup.sh              │
│    (Prepare Docker environment)      │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ 2. Identify target type             │
│    (APK / IPA / Web)               │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ 3. Extract via Docker               │
│    (SEQUENTIAL)                    │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ 4. Analyze via Docker               │
│    (PARALLEL - 6 tasks)           │
│    - Manifest analysis             │
│    - Endpoint extraction           │
│    - Secrets detection             │
│    - Certificate analysis          │
│    - Network security              │
│    - Third-party SDKs             │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ 5. Deobfuscate (PARALLEL)         │
│    - Decode Base64/hex/XOR         │
│    - Trace crypto                  │
│    - Anti-analysis detection       │
│    - Decoy vs real classification  │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ 6. Report                          │
│    findings/[app]-[date]/         │
└─────────────────────────────────────┘
```

## Docker Images

| Image | Purpose | Pre-pull |
|-------|---------|----------|
| `cryptax/android-re` | APK analysis (jadx, apktool) | 3 (1.7GB) |
| `trufflesecurity/trufflehog` | Secret scanning | 2 |
| `zricethezav/gitleaks` | Secret scanning | 1 (smallest) |
| `node:20-alpine` | Web bundle beautify | on-demand |

## File Structure

```
reverse-mobile/
├── SKILLS.md           # Docker-first reverse engineering skill (Chinese)
├── AGENT_TEAMS.md      # 5-role team configuration (Chinese)
├── docker-setup.sh     # Docker readiness script
├── README.md           # This file
├── CLAUDE.md           # Project instructions
└── findings/          # Analysis output directory
```

## Raw File URLs

After pushing to GitHub, replace `{USERNAME}/{REPO}` with your repo:

| File | Raw URL |
|------|---------|
| SKILLS.md | `https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/SKILLS.md` |
| AGENT_TEAMS.md | `https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/AGENT_TEAMS.md` |
| docker-setup.sh | `https://raw.githubusercontent.com/{USERNAME}/{REPO}/main/docker-setup.sh` |

## Tips

1. **Always run `./docker-setup.sh` first** before starting analysis
2. **Use raw GitHub URLs** for AI agents to read the skill files directly
3. **Docker-first**: Always try Docker first, local tools are only fallback
4. **Parallel analysis**: Use Task tool for parallel analysis tasks

## Troubleshooting

### Docker daemon not running
```bash
# macOS
open -a Docker

# Linux
sudo systemctl start docker
```

### Image pull failed
```bash
# Manual pull
docker pull cryptax/android-re:latest
docker pull trufflesecurity/trufflehog:latest
docker pull zricethezav/gitleaks:latest
```

### Permission issues
```bash
# Ensure -u $(id -u):$(id -g) is used in docker run
docker run --rm -u $(id -u):$(id -g) -v /path:/work cryptax/android-re jadx ...
```

## Deploy to GitHub

```bash
cd /Users/user/Workspaces/pedalaman/reverse-mobile
git init
git add .
git commit -m "Initial commit: Docker-first reverse engineering setup"
git branch -M main
git remote add origin https://github.com/{USERNAME}/{REPO}.git
git push -u origin main
```
