# --------------------------------------------------
# dev docker file, to test
# --------------------------------------------------
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y curl sudo xz-utils && \
    rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# create non-root user (replace default ubuntu user which holds UID 1000)
# --------------------------------------------------
ARG USERNAME=arpad
RUN userdel -r ubuntu 2>/dev/null; \
    useradd -m -u 1000 -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# --------------------------------------------------
# single-user nix install (no daemon needed)
# --------------------------------------------------
SHELL ["/bin/bash", "-c"]
RUN sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon --yes
RUN mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

ENV BASH_ENV="/home/${USERNAME}/.nix-profile/etc/profile.d/nix.sh"
ENV USER=${USERNAME}

WORKDIR /home/${USERNAME}/ahome
CMD [ "bash" ]
