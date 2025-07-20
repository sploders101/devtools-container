FROM debian:bookworm AS base

RUN apt-get update && apt-get install -y \
  build-essential \
  curl \
  git \
  wget \
  desktop-file-utils \
  nodejs \
  npm \
  binaryen \
  python3 \
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
RUN git clone --branch personal https://github.com/sploders101/zellij
RUN cd zellij && cargo make install /home/dev/.cargo/bin/zellij
RUN cargo install --git https://github.com/rhaiscript/rhai-lsp.git rhai-cli
RUN cargo install --git https://github.com/astral-sh/ruff.git --tag 0.11.8 ruff


FROM base

USER root:root
RUN curl -sSL https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info | tic -x -
RUN mkdir /app
USER dev:dev
ENV SHELL=/bin/bash
WORKDIR /app

COPY --from=tools-builder /home/dev/.cargo/bin/hx /home/dev/.cargo/bin/hx
COPY --from=tools-builder /home/dev/.cargo/bin/zellij /home/dev/.cargo/bin/zellij
COPY --from=tools-builder /home/dev/.cargo/bin/cargo-make /home/dev/.cargo/bin/cargo-make
COPY --from=tools-builder /home/dev/.cargo/bin/mandown /home/dev/.cargo/bin/mandown
COPY --from=tools-builder /home/dev/.cargo/bin/gitui /home/dev/.cargo/bin/gitui
COPY --from=tools-builder /home/dev/.cargo/bin/rhai /home/dev/.cargo/bin/rhai
COPY --from=tools-builder /home/dev/.cargo/bin/ruff /home/dev/.cargo/bin/ruff
COPY --from=tools-builder /home/dev/helix-editor/runtime /home/dev/.config/helix/runtime
COPY configs/helix/config.toml /home/dev/.config/helix/config.toml

RUN npm i --global pyright vscode-langservers-extracted typescript typescript-language-server \
	@vue/language-server yaml-language-server@next svelte-language-server \
	dockerfile-language-server-nodejs @microsoft/compose-language-service bash-language-server \
	@ansible/ansible-language-server perlnavigator-server intelephense awk-language-server \
  emmet-ls
