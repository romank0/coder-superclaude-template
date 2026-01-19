# Claude Code Development Template

A Coder template for AI-assisted development with Claude Code, SuperClaude, and essential MCP servers.

## Features

- **Claude Code CLI** - Anthropic's official CLI for Claude
- **SuperClaude** - Enhanced prompts and commands for Claude Code
- **Ralph Wiggum Plugin** - Iterative AI development loop
- **MCP Servers** - Pre-configured Model Context Protocol servers:
  - Filesystem - Read/write files in workspace
  - Memory - Persistent memory across sessions
  - Context7 - Up-to-date library documentation
  - Sequential Thinking - Multi-step reasoning
  - Playwright - Browser automation and testing
  - Chrome DevTools - Browser debugging and inspection
  - Serena - Additional AI capabilities
- **Coder MCP** - Workspace management integration (via claude-code module)
- **VS Code** - Code-server (VS Code in browser)
- **GitHub Integration** - SSH key support and gh CLI
- **Persistent Storage** - Home directory persists across restarts
- **tmux Sessions** - Persistent Claude Code sessions with task reporting

## Quick Start

### 1. Push Template to Coder

```bash
# Navigate to template directory
cd coder-superclaude-template

# Push to your Coder instance
coder templates push claude-code
```

### 2. Create a Workspace

From the Coder dashboard or CLI:

```bash
coder create my-workspace --template claude-code
```

### 3. Prerequisites on Host Machine

Ensure Claude credentials and SSH keys exist on the host at the paths you'll configure:

```bash
# Claude Code logged in (default path: /root/.claude)
sudo claude login

# SSH key for GitHub (default path: /root/.ssh)
sudo ls /root/.ssh/id_ed25519  # or id_rsa
```

For better security, consider using a dedicated user instead of root:

```bash
# Create dedicated user for git credentials
sudo useradd -m coder-git
sudo -u coder-git ssh-keygen -t ed25519 -f /home/coder-git/.ssh/id_ed25519
# Add public key to GitHub, then use /home/coder-git/.ssh as ssh_host_path
```

### 4. Configure Parameters

When creating the workspace:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git_repo` | Repository to clone - supports SSH, HTTPS, or shorthand (`owner/repo`) | (empty) |
| `dotfiles_repo` | Your dotfiles repository (optional) | (empty) |
| `cpu` | CPU cores | 4 |
| `memory` | Memory in GB | 8 |
| `ssh_host_path` | Path to SSH keys on the host machine | `/root/.ssh` |
| `claude_host_path` | Path to Claude credentials directory on the host | `/root/.claude` |

**What gets mounted:**
- `claude_host_path` → `/tmp/.claude-host` (read-only, only `.credentials.json` is copied)
- `ssh_host_path` → `~/.ssh-host` → `~/.ssh` (read-only, copied on startup with proper permissions)

## Usage

### Connect via Terminal

```bash
coder ssh my-workspace
```

### Use Claude Code

```bash
# Start Claude Code in your project
cd ~/workspace/your-repo
claude

# Or use SuperClaude commands
claude /sc:help
```

### Setup GitHub Repository

If you didn't specify a repo at creation time:

```bash
# Interactive setup script
setup-github

# Or manually with SSH key
cd ~/workspace
git clone git@github.com:owner/repo.git

# Or authenticate with gh CLI
gh auth login
gh repo clone owner/repo
```

## MCP Server Configuration

MCP servers are pre-configured in `~/.config/claude-code/mcp/config.json` and dynamically added to `~/.claude.json` on startup.

### Pre-installed MCP Servers

| Server | Description |
|--------|-------------|
| `filesystem` | Read/write files in workspace directory |
| `memory` | Persistent memory across sessions |
| `context7` | Up-to-date library documentation via Context7 |
| `sequential-thinking` | Multi-step reasoning and analysis |
| `playwright` | Browser automation and testing |
| `chrome-devtools` | Chrome DevTools debugging |
| `serena` | Additional AI capabilities |
| `coder` | Workspace management (added by claude-code module) |

### Add More Servers

Edit `~/.claude.json` to add additional MCP servers:

```json
{
  "projects": {
    "/home/coder/workspace/your-repo": {
      "mcpServers": {
        "your-server": {
          "command": "npx",
          "args": ["-y", "@your/mcp-server"]
        }
      }
    }
  }
}
```

### Popular MCP Servers

Additional MCP servers you can add:

- `@anthropic-ai/claude-mcp-server-brave-search` - Web search
- `@anthropic-ai/claude-mcp-server-puppeteer` - Browser automation
- `@anthropic-ai/claude-mcp-server-postgres` - PostgreSQL access
- `@anthropic-ai/claude-mcp-server-sqlite` - SQLite database

## SSH Key Setup

SSH keys are mounted from the host path configured via `ssh_host_path` parameter (default: `/root/.ssh`) and copied to `~/.ssh` with proper permissions on startup.

### Option 1: Use Host Keys (Recommended)

Ensure SSH keys exist on the Coder host at your configured path:

```bash
# On host machine (default path)
sudo ls -la /root/.ssh/

# Or with a dedicated user (more secure)
ls -la /home/coder-git/.ssh/
```

### Option 2: Interactive Setup

```bash
# Inside workspace - interactive setup
setup-github
```

### Option 3: Generate New Key

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
cat ~/.ssh/id_ed25519.pub
# Add this to GitHub Settings > SSH Keys
```

## Pre-installed Tools

The Docker image includes:

- **Languages**: Node.js 20.x (LTS), Python 3 with pip/venv
- **Package Managers**: npm, pnpm, uv (Python)
- **Editors**: vim, neovim, code-server (VS Code)
- **CLI Tools**: git, gh (GitHub CLI), tmux, htop, jq, curl, wget
- **Browsers**: Chromium (for Playwright and DevTools MCP)
- **Build Tools**: build-essential

## Customization

### Environment Variables

Add to `coder_agent.main.env` in `main.tf`:

```hcl
env = {
  MY_CUSTOM_VAR = "value"
}
```

### Pre-installed Tools

Modify `build/Dockerfile` to add more tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    your-package \
    && rm -rf /var/lib/apt/lists/*
```

### Claude Code Module Options

The template uses the official `claude-code` module with these options:

```hcl
module "claude-code" {
  source       = "registry.coder.com/coder/claude-code/coder"
  version      = "1.4.0"
  agent_id     = coder_agent.main.id
  folder       = local.repo_folder

  # Background tmux session for persistent Claude Code
  experiment_use_tmux     = true
  experiment_report_tasks = true
}
```

## Troubleshooting

### Claude Code not authenticated

```bash
# Check if credentials are mounted
ls -la ~/.claude/

# If missing, login on the HOST machine at your configured claude_host_path:
# Default: sudo claude login (creates /root/.claude/.credentials.json)
# Or for a specific user: sudo -u myuser claude login
```

### SSH key not working

```bash
# Test SSH connection
ssh -T git@github.com

# Check if keys are properly copied
ls -la ~/.ssh/

# If permissions issues, keys should be:
# - Private keys: 600
# - Public keys: 644
# - .ssh directory: 700
```

### MCP servers not loading

```bash
# Check config file
cat ~/.claude.json | jq '.projects'

# Verify MCP servers are installed
npx @upstash/context7-mcp --version

# Test MCP server manually
npx -y @modelcontextprotocol/server-filesystem /home/coder/workspace
```

### Permission issues with mounted volumes

```bash
# The startup script should fix permissions automatically
# If issues persist, manually fix:
sudo chown -R coder:coder ~/.claude
sudo chown -R coder:coder ~/.ssh
```

## Architecture

```
coder-superclaude-template/
├── main.tf                    # Terraform configuration
│   ├── claude-code module     # Official Coder module for Claude Code
│   ├── coder_agent            # Agent with startup script
│   ├── coder_app (VS Code)    # Code-server web app
│   ├── coder_app (Terminal)   # Terminal access
│   └── docker_container       # Workspace container
├── build/
│   ├── Dockerfile             # Container image with tools
│   ├── mcp-config.json        # Default MCP server config
│   └── setup-github.sh        # GitHub setup script
└── README.md
```

## License

MIT
