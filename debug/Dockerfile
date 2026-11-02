# --------------------------------------------------
# throwaway machines for testing installs. `base` is a
# fresh box with only curl and git, what the one-line
# installers meet; `nix` adds a single-user nix
# --------------------------------------------------
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y curl git sudo xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# non-root user and its shell (replace default ubuntu user which holds UID 1000)
# --------------------------------------------------
ARG USERNAME=arpad
RUN userdel -r ubuntu 2>/dev/null; \
    useradd -m -u 1000 -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${USERNAME}
ENV USER=${USERNAME}
WORKDIR /home/${USERNAME}
CMD [ "bash" ]

# --------------------------------------------------
# single-user nix install (no daemon needed)
# --------------------------------------------------
FROM base AS nix
SHELL ["/bin/bash", "-c"]
RUN sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon --yes
RUN mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
ENV BASH_ENV="/home/${USERNAME}/.nix-profile/etc/profile.d/nix.sh"
WORKDIR /home/${USERNAME}/ahome
