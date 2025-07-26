FROM debian:bookworm AS base

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
  build-essential \
  curl \
  git \
  wget \
  desktop-file-utils \
  nodejs \
  npm \
  binaryen \
  python3 \
	python3-pip \
	protobuf-compiler \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash dev
USER dev:dev

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="/home/dev/.cargo/bin:${PATH}"

RUN npm config set prefix '~/.local/'
RUN mkdir -p ~/.local/bin
ENV PATH="/home/dev/.local/bin:${PATH}"

FROM base AS tools-builder

RUN cargo install cargo-make
RUN cargo install mandown
USER root:root
RUN apt-get update && apt-get install -y cmake
USER dev:dev
WORKDIR /home/dev
RUN cargo install --locked -- gitui
RUN git clone --branch personal https://github.com/sploders101/helix-editor.git
RUN cd helix-editor && cargo install --path helix-term --locked
RUN rm -rf runtime/grammars/sources
RUN git clone --branch personal https://github.com/sploders101/zellij
RUN cd zellij && cargo make install /home/dev/.cargo/bin/zellij
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=ghcr.io/astral-sh/ruff:latest /ruff /bin/
COPY --from=golang:bookworm /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go install golang.org/x/tools/gopls@latest
RUN go install github.com/bufbuild/buf/cmd/buf@v1.55.1


FROM base

USER root:root
RUN curl -sSL https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info | tic -x -
RUN mkdir /app
USER dev:dev
ENV SHELL=/bin/bash
WORKDIR /app

ENV PATH="/usr/local/go/bin:/home/dev/go/bin:${PATH}"

# Copy bin directories
COPY --chown=dev:dev --from=tools-builder /home/dev/.cargo/bin /home/dev/.cargo/bin
COPY --chown=dev:dev --from=tools-builder /home/dev/go/bin /home/dev/go/bin
COPY --chown=dev:dev --from=golang:bookworm /usr/local/go /usr/local/go

# Copy Helix configs
COPY --chown=dev:dev --from=tools-builder /home/dev/helix-editor/runtime /home/dev/.config/helix/runtime
COPY --chown=dev:dev configs/helix/config.toml /home/dev/.config/helix/config.toml
COPY --chown=dev:dev configs/helix/languages.toml /home/dev/.config/helix/languages.toml

# Install JS-based language servers
RUN npm i --global pyright vscode-langservers-extracted typescript typescript-language-server \
	@vue/language-server yaml-language-server@next svelte-language-server \
	dockerfile-language-server-nodejs @microsoft/compose-language-service bash-language-server \
	@ansible/ansible-language-server perlnavigator-server intelephense awk-language-server \
  emmet-ls
