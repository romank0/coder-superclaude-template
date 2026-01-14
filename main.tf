terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 0.17"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# Official Claude Code module from Coder registry
module "claude-code" {
  source       = "registry.coder.com/coder/claude-code/coder"
  version      = "1.4.0"
  agent_id     = coder_agent.main.id
  folder       = "/home/coder/workspace"

  # Disable module's npm install - we handle it with sudo in startup script
  install_claude_code = false

  # Run in background with tmux for persistent sessions
  experiment_use_tmux     = true
  experiment_report_tasks = true
}

provider "coder" {}
provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Parameters for customization
data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git Repository"
  description  = "Repository to clone (SSH: git@host:path.git, HTTPS: https://host/path.git, or shorthand: owner/repo for GitHub)"
  type         = "string"
  default      = ""
  mutable      = true
  order        = 1
}

data "coder_parameter" "dotfiles_repo" {
  name         = "dotfiles_repo"
  display_name = "Dotfiles Repository"
  description  = "Personal dotfiles repo (optional)"
  type         = "string"
  default      = ""
  mutable      = true
  order        = 2
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  type         = "number"
  default      = 4
  mutable      = false
  order        = 3
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  type         = "number"
  default      = 8
  mutable      = false
  order        = 4
}


resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e

    # SSH keys are mounted read-only to .ssh-host, copy to writable .ssh
    # Use sudo to read root-owned mounted files, then fix ownership
    sudo rm -rf ~/.ssh 2>/dev/null || true
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    if [ -d ~/.ssh-host ]; then
      # Copy all files from ssh-host (root-owned) to .ssh
      for f in $(sudo ls ~/.ssh-host/ 2>/dev/null); do
        sudo cp ~/.ssh-host/"$f" ~/.ssh/ 2>/dev/null || true
      done
      sudo chown -R coder:coder ~/.ssh/ 2>/dev/null || true
      chmod 600 ~/.ssh/id_* 2>/dev/null || true
      chmod 644 ~/.ssh/*.pub 2>/dev/null || true
    fi
    # Add common git hosts to known_hosts
    ssh-keyscan github.com gitlab.com bitbucket.org ssh.dev.azure.com >> ~/.ssh/known_hosts 2>/dev/null || true

    # Fix permissions on mounted .claude directory (owned by root from host)
    sudo chown -R coder:coder ~/.claude 2>/dev/null || true

    # Configure git
    git config --global user.name "${data.coder_workspace_owner.me.name}"
    git config --global user.email "${data.coder_workspace_owner.me.email}"
    git config --global init.defaultBranch main

    # Install Claude Code if not present
    if ! command -v claude &> /dev/null; then
      echo "Installing Claude Code..."
      sudo npm install -g @anthropic-ai/claude-code
    fi

    # Claude credentials are mounted from host machine
    if [ -f ~/.claude/.credentials.json ]; then
      echo "Claude credentials loaded from host machine."
    else
      echo "Warning: No Claude credentials found. Run 'claude login' on host machine."
    fi

    # Install SuperClaude commands
    if [ ! -d ~/.claude/commands/sc ]; then
      echo "Installing SuperClaude..."
      pip3 install --user superclaude 2>/dev/null || true
      ~/.local/bin/superclaude install 2>/dev/null || superclaude install 2>/dev/null || true
    fi

    # Install Ralph Wiggum plugin (iterative AI development loop)
    if [ ! -d ~/.claude/plugins/ralph-wiggum ]; then
      echo "Installing Ralph Wiggum plugin..."
      mkdir -p ~/.claude/plugins
      git clone --depth 1 --filter=blob:none --sparse https://github.com/anthropics/claude-code.git /tmp/claude-code-plugins 2>/dev/null || true
      cd /tmp/claude-code-plugins && git sparse-checkout set plugins/ralph-wiggum 2>/dev/null || true
      cp -r /tmp/claude-code-plugins/plugins/ralph-wiggum ~/.claude/plugins/ 2>/dev/null || true
      rm -rf /tmp/claude-code-plugins
      chmod +x ~/.claude/plugins/ralph-wiggum/hooks/*.sh 2>/dev/null || true
    fi

    # Setup MCP servers directory
    mkdir -p ~/.config/claude-code/mcp

    # Install Context7 MCP
    if ! command -v npx &> /dev/null || ! npx @context7/mcp --version &> /dev/null; then
      sudo npm install -g @context7/mcp 2>/dev/null || true
    fi

    # Configure MCP servers in Claude config
    if [ -f ~/.claude.json ]; then
      # Add MCP servers to the project config (preserve coder MCP from module)
      jq --arg workspace "/home/coder/workspace" '
        .projects[$workspace].mcpServers += {
          "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/coder/workspace"]
          },
          "memory": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-memory"]
          },
          "context7": {
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp"]
          },
          "sequential-thinking": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
          },
          "playwright": {
            "command": "npx",
            "args": ["-y", "@playwright/mcp@latest"]
          },
          "chrome-devtools": {
            "command": "npx",
            "args": ["-y", "chrome-devtools-mcp"]
          },
          "serena": {
            "command": "uvx",
            "args": ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"]
          }
        }
      ' ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
      echo "MCP servers configured."
    fi

    # Clone repository if specified
    if [ -n "${data.coder_parameter.git_repo.value}" ]; then
      REPO_INPUT="${data.coder_parameter.git_repo.value}"

      # Extract repo name from various URL formats
      REPO_NAME=$(basename "$REPO_INPUT" .git)

      if [ ! -d ~/workspace/$REPO_NAME ]; then
        mkdir -p ~/workspace

        # Check if it's already a full URL (SSH or HTTPS)
        if echo "$REPO_INPUT" | grep -qE '^(git@|https://|ssh://|git://)'; then
          # Full URL provided - use as-is, try SSH first then HTTPS
          if echo "$REPO_INPUT" | grep -qE '^https://'; then
            # HTTPS URL - also try SSH variant
            git clone "$REPO_INPUT" ~/workspace/$REPO_NAME 2>/dev/null || \
            git clone "$(echo "$REPO_INPUT" | sed 's|https://\([^/]*\)/|git@\1:|')" ~/workspace/$REPO_NAME
          else
            # SSH URL - also try HTTPS variant
            git clone "$REPO_INPUT" ~/workspace/$REPO_NAME 2>/dev/null || \
            git clone "$(echo "$REPO_INPUT" | sed 's|git@\([^:]*\):|https://\1/|')" ~/workspace/$REPO_NAME
          fi
        else
          # Shorthand format (owner/repo) - assume GitHub
          git clone "git@github.com:$REPO_INPUT.git" ~/workspace/$REPO_NAME 2>/dev/null || \
          git clone "https://github.com/$REPO_INPUT.git" ~/workspace/$REPO_NAME
        fi
      fi
    fi

    # Apply dotfiles if specified
    if [ -n "${data.coder_parameter.dotfiles_repo.value}" ]; then
      coder dotfiles -y "${data.coder_parameter.dotfiles_repo.value}" 2>/dev/null || true
    fi

    echo "Setup complete!"
  EOT

  env = {
    GIT_AUTHOR_NAME   = data.coder_workspace_owner.me.name
    GIT_AUTHOR_EMAIL  = data.coder_workspace_owner.me.email
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }
}

# VS Code Web App
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:8080/?folder=/home/coder/workspace"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
}

# Terminal App
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "/bin/bash"
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context    = "./build"
    dockerfile = "Dockerfile"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.image_id
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = data.coder_workspace.me.name

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  cpu_set = "0-${data.coder_parameter.cpu.value - 1}"
  memory  = data.coder_parameter.memory.value * 1024

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  # Mount Claude credentials from host root user
  volumes {
    container_path = "/home/coder/.claude"
    host_path      = "/root/.claude"
    read_only      = false
  }

  # Mount SSH keys from host root user (read-only, copied to .ssh on startup)
  volumes {
    container_path = "/home/coder/.ssh-host"
    host_path      = "/root/.ssh"
    read_only      = true
  }
}
