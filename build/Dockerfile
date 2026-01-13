FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    gh \
    vim \
    neovim \
    tmux \
    htop \
    jq \
    unzip \
    zip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    openssh-client \
    sudo \
    locales \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Install useful MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-memory \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp \
    @playwright/mcp@latest \
    chrome-devtools-mcp \
    || true

# Install uv for Python package management (needed for Serena)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

# Install Chrome for DevTools MCP
RUN apt-get update && apt-get install -y \
    chromium-browser \
    && rm -rf /var/lib/apt/lists/*

# Install code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create coder user
RUN useradd --create-home --shell /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Switch to coder user
USER coder
WORKDIR /home/coder

# Create necessary directories
RUN mkdir -p \
    /home/coder/.ssh \
    /home/coder/.config/claude-code \
    /home/coder/.config/claude-code/mcp \
    /home/coder/.claude \
    /home/coder/workspace

# Set proper permissions
RUN chmod 700 /home/coder/.ssh

# Install SuperClaude
RUN git clone https://github.com/NomenAK/SuperClaude.git /home/coder/.claude/superclaude 2>/dev/null || true

# Configure default MCP servers
COPY --chown=coder:coder mcp-config.json /home/coder/.config/claude-code/mcp/config.json

# Add setup scripts
COPY --chown=coder:coder setup-github.sh /home/coder/.local/bin/setup-github
RUN chmod +x /home/coder/.local/bin/setup-github

# Set environment variables
ENV PATH="/home/coder/.local/bin:/root/.local/bin:/home/coder/.cargo/bin:${PATH}"
ENV SHELL=/bin/bash

# Expose code-server port
EXPOSE 8080

# Start code-server by default
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "none", "/home/coder/workspace"]
