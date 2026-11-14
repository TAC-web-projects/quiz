FROM mcr.microsoft.com/devcontainers/base:ubuntu

# --- System tools: Inkscape converts the compiled PDF to SVG ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        inkscape fonts-dejavu-core wget ca-certificates jq perl fontconfig \
    && rm -rf /var/lib/apt/lists/*


ARG USERNAME=vscode

# --- TinyTeX: install as root, system-wide in /opt ---
USER root
ENV TINYTEX_DIR=/opt
RUN wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh \
    # Stable folder name that works on Intel (x86_64) and ARM (aarch64)
    && ln -s /opt/.TinyTeX/bin/$(uname -m)-linux /opt/.TinyTeX/bin/active

# Put TinyTeX's bin folder on PATH directly; no tlmgr path add needed
ENV PATH="/opt/.TinyTeX/bin/active:${PATH}"

# --- LaTeX packages for the TikZ diagrams ---
RUN tlmgr install luaotfload luatex85 standalone pgf pgfplots xcolor amsmath amsfonts \
    && luaotfload-tool -u \
    # Let your user run tlmgr install later without sudo
    && chown -R ${USERNAME}:${USERNAME} /opt/.TinyTeX

RUN ARCH=$(dpkg --print-architecture) \
    && VERSION=$(curl -fsSL https://api.github.com/repos/quarto-dev/quarto-cli/releases/latest | jq -r .tag_name | sed 's/^v//') \
    && curl -fsSL -o /tmp/quarto.deb \
       "https://github.com/quarto-dev/quarto-cli/releases/download/v${VERSION}/quarto-${VERSION}-linux-${ARCH}.deb" \
    && apt-get update \
    && apt-get install -y /tmp/quarto.deb \
    && rm -rf /tmp/quarto.deb /var/lib/apt/lists/* \
    && quarto --version

USER ${USERNAME}
# # --- TinyTeX, installed system-wide in /opt so any user can run it ---
# ENV TINYTEX_DIR=/home/vscode
# RUN wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh 

# # --- LaTeX packages the TikZ diagrams need ---
# RUN /home/vscode/.TinyTeX/bin/*/tlmgr install luaotfload standalone pgf pgfplots xcolor amsmath amsfonts \
#     && /home/vscode/.TinyTeX/bin/*/tlmgr path add \ 
#     && luaotfload-tool -u

# # Install the latest Quarto CLI release (works on both amd64 and arm64 / Apple Silicon)
