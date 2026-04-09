# GitHub Copilot Instructions — KSC AIBox

## Project Context

**KSC AIBox** is an automated deployment project for Jinshan Government AI All-in-One Machine, based on Huawei Ascend 910B NPU + openEuler + Ansible.

### Key Files

Before working on this project, read:
- `AGENTS.md` — **Master Skills Index** (54 AI Agent Skills)
- `QWEN.md` — Project context (version/hardware/deployment)
- `docs/Agent.md` — AI Agent collaboration guide
- `docs/SKILL.md` — Implementation skills and troubleshooting experience

### Key Paths

| Path | Purpose |
|------|---------|
| `/ksc_aibox` | AI machine root |
| `/ksc_aibox/apps/` | Applications |
| `/ksc_aibox/models/` | Model files |
| `/ksc_aibox/data/` | Data directory |
| `/ksc_aibox/docker/` | Docker data |

---

## AI Agent Skills (54 Skills)

This project contains **54 AI Agent Skills** defined in `src/agent-skills/`. Each skill directory contains a `SKILL.md` file with detailed execution guidelines.

### Skill Categories

| Category | Skills | Coverage |
|----------|--------|----------|
| Environment Deployment | 5 | Docker/NPU Driver/CANN/ATC Model Convert/HCCL Test |
| AscendC Operator Dev | 12 | Full pipeline: requirements→design→code→compile→precision→performance→optimization |
| CATLASS Operator | 4 | Matrix operator design, development, optimization |
| Triton Operator | 9 | Triton operator design, development, precision/performance evaluation |
| Megatron Migration | 4 | Change analysis, commit tracking, impact mapping, migration generation |
| MindSpeed LLM Testing | 7 | Code comprehension, test generation, coverage analysis |
| NPU Operations | 6 | Device management, adapter review, profiling analysis |
| General Tools | 7 | Bug fixing, test generation, Python refactoring, security audit |

### Using Skills

When working on tasks, reference the `AGENTS.md` skills index to find the appropriate skill, then read `src/agent-skills/<skill-name>/SKILL.md` for detailed execution guidelines.

Skill directories may contain:
- `references/` — Reference documentation
- `scripts/` — Executable scripts
- `templates/` — Code templates

---

## Coding Conventions

- **Playbooks**: YAML format, 2-space indentation
- **Scripts**: Bash, follow `.editorconfig`
- **Variables**: snake_case with prefix grouping
- **Language**: Respond in Chinese by default

## Security

- Never commit API keys or secrets
- Read existing code before modifying
- Follow project coding style
- Run verification commands after changes

## Skills Update

Skills are synced weekly from upstream `https://gitcode.com/Ascend/agent-skills`:
```bash
./scripts/sync-agent-skills.sh
```
