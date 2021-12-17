####################
##   Dart Stage   ##
####################
FROM drydock-prod.workiva.net/workiva/dart2_base_image:1 as build


# setup ssh
ARG GIT_SSH_KEY
ARG KNOWN_HOSTS_CONTENT

# Setting up ssh and ssh-agent for git-based dependencies
RUN mkdir /root/.ssh/ && \
  echo "$KNOWN_HOSTS_CONTENT" > "/root/.ssh/known_hosts" && \
  chmod 700 /root/.ssh/ && \
  umask 0077 && echo "$GIT_SSH_KEY" >/root/.ssh/id_rsa && \
  eval "$(ssh-agent -s)" && \
  ssh-add /root/.ssh/id_rsa

WORKDIR /build/

COPY pubspec.yaml /build/

COPY . /build/

# Build Environment Vars Required for wdesk app build, semver audit, and ddev's
# usage reporting.
ARG GIT_COMMIT
ARG GIT_TAG
ARG GIT_BRANCH
ARG GIT_MERGE_HEAD
ARG GIT_MERGE_BRANCH
ARG GIT_HEAD_REPO
ARG BUILD_ID

RUN timeout 5m pub get

# Package up the artifacts
WORKDIR /build/

FROM scratch