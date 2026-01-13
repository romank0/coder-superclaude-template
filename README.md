# Claude Code Development Template

A Coder template for AI-assisted development with Claude Code, SuperClaude, and essential MCP servers.

## Features

- **Claude Code CLI** - Anthropic's official CLI for Claude
- **SuperClaude** - Enhanced prompts and commands for Claude Code
- **MCP Servers** - Pre-configured Model Context Protocol servers:
  - Filesystem - Read/write files in workspace
  - Memory - Persistent memory across sessions
  - Context7 - Up-to-date library documentation
  - Fetch - Web fetching capabilities
- **VS Code** - Code-server (VS Code in browser)
- **GitHub Integration** - SSH key support and gh CLI
- **Persistent Storage** - Home directory persists across restarts

## Quick Start

### 1. Push Template to Coder

```bash
# Navigate to template directory
cd claude-code-template

# Push to your Coder instance
coder templates push claude-code
```

### 2. Create a Workspace

From the Coder dashboard or CLI:

```bash
coder create my-workspace --template claude-code
```

### 3. Prerequisites on Host Machine

Ensure the **root user** on your Coder host has:

```bash
# Claude Code logged in
sudo claude login

# SSH key for GitHub
sudo ls /root/.ssh/id_ed25519  # or id_rsa
```

These are automatically mounted into workspaces.

### 4. Configure Parameters

When creating the workspace:

| Parameter | Description |
|-----------|-------------|
| `github_repo` | Repository to clone (e.g., `owner/repo`) |
| `dotfiles_repo` | Your dotfiles repository (optional) |
| `cpu` | CPU cores (default: 4) |
| `memory` | Memory in GB (default: 8) |

**Auto-mounted from host `/root/`:**
- `~/.claude` - Claude Code credentials
- `~/.ssh` - SSH keys (read-only)

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
# With SSH key configured
cd ~/workspace
git clone git@github.com:owner/repo.git

# Or authenticate with gh CLI
gh auth login
gh repo clone owner/repo
```

## MCP Server Configuration

MCP servers are pre-configured in `~/.config/claude-code/mcp/config.json`.

### Add More Servers

Edit the config file to add additional MCP servers:

```json
{
  "mcpServers": {
    "your-server": {
      "command": "npx",
      "args": ["-y", "@your/mcp-server"]
    }
  }
}
```

### Available MCP Servers

Popular MCP servers you can add:

- `@anthropic-ai/claude-mcp-server-brave-search` - Web search
- `@anthropic-ai/claude-mcp-server-puppeteer` - Browser automation
- `@anthropic-ai/claude-mcp-server-postgres` - PostgreSQL access
- `@anthropic-ai/claude-mcp-server-sqlite` - SQLite database

## SSH Key Setup

### Option 1: Paste During Creation

Paste your SSH private key content when creating the workspace.

### Option 2: Add After Creation

```bash
# Copy your key into the workspace
coder ssh my-workspace
mkdir -p ~/.ssh
# Paste your key into ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### Generate New Key

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
cat ~/.ssh/id_ed25519.pub
# Add this to GitHub Settings > SSH Keys
```

## Customization

### Environment Variables

Add to `coder_agent.main.env` in `main.tf`:

```hcl
env = {
  ANTHROPIC_API_KEY = data.coder_parameter.anthropic_api_key.value
  MY_CUSTOM_VAR     = "value"
}
```

### Pre-installed Tools

Modify `build/Dockerfile` to add more tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    your-package \
    && rm -rf /var/lib/apt/lists/*
```

### Default Extensions

Add VS Code extensions in the startup script or Dockerfile.

## Troubleshooting

### Claude Code not authenticated

```bash
# Check if credentials are mounted
ls -la ~/.claude/

# If missing, login on the HOST machine as root:
# sudo claude login
```

### SSH key not working

```bash
# Test SSH connection
ssh -T git@github.com

# Check if keys are mounted
ls -la ~/.ssh/

# If missing, ensure keys exist on HOST:
# sudo ls -la /root/.ssh/
```

### MCP servers not loading

```bash
# Check config file
cat ~/.config/claude-code/mcp/config.json

# Test MCP server manually
npx -y @context7/mcp --version
```

## License

MIT
