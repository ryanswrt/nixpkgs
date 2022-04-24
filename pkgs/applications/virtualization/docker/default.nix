{ lib, callPackage, fetchFromGitHub }:

with lib;

rec {
  dockerGen = { version, rev, sha256, moby-src, runcRev, runcSha256
    , containerdRev, containerdSha256, tiniRev, tiniSha256, buildxSupport ? true
    , composeSupport ? true
      # package dependencies
      , stdenv, fetchFromGitHub, fetchpatch, buildGoPackage
      , makeWrapper, installShellFiles, pkg-config, glibc
      , go-md2man, go, containerd, runc, docker-proxy, tini, libtool
      , sqlite, iproute2, lvm2, systemd, docker-buildx, docker-compose_2
      , btrfs-progs, iptables, e2fsprogs, xz, util-linux, xfsprogs, git
      , procps, libseccomp, rootlesskit, slirp4netns, fuse-overlayfs
      , nixosTests
      , clientOnly ? !stdenv.isLinux, symlinkJoin
    }:
  let
    docker-runc = runc.overrideAttrs (oldAttrs: {
      name = "docker-runc-${version}";
      inherit version;
      src = fetchFromGitHub {
        owner = "opencontainers";
        repo = "runc";
        rev = runcRev;
        sha256 = runcSha256;
      };
      # docker/runc already include these patches / are not applicable
      patches = [];
    });

    docker-containerd = containerd.overrideAttrs (oldAttrs: {
      name = "docker-containerd-${version}";
      inherit version;
      src = fetchFromGitHub {
        owner = "containerd";
        repo = "containerd";
        rev = containerdRev;
        sha256 = containerdSha256;
      };
    in buildGoPackage ((optionalAttrs (!clientOnly) {

      inherit docker-runc docker-containerd docker-proxy docker-tini moby;

    }) // rec {
      inherit version rev;

      pname = "docker";

      src = fetchFromGitHub {
        owner = "docker";
        repo = "cli";
        rev = "v${version}";
        sha256 = sha256;
      };

      goPackagePath = "github.com/docker/cli";

      nativeBuildInputs =
        [ makeWrapper pkg-config go-md2man go libtool installShellFiles ];
      buildInputs =
        optionals (!clientOnly) [ sqlite lvm2 btrfs-progs systemd libseccomp ]
        ++ plugins;

      patches = [
        # This patch incorporates code from a PR fixing using buildkit with the ZFS graph driver.
        # It could be removed when a version incorporating this patch is released.
        (fetchpatch {
          name = "buildkit-zfs.patch";
          url = "https://github.com/moby/moby/pull/43136.patch";
          sha256 = "1WZfpVnnqFwLMYqaHLploOodls0gHF8OCp7MrM26iX8=";
        })
      ];

      postPatch = ''
        patchShebangs man scripts/build/
        substituteInPlace ./scripts/build/.variables --replace "set -eu" ""
      '' + optionalString (plugins != [ ]) ''
        substituteInPlace ./cli-plugins/manager/manager_unix.go --replace /usr/libexec/docker/cli-plugins \
            "${pluginsRef}/libexec/docker/cli-plugins"
      '';

      # Keep eyes on BUILDTIME format - https://github.com/docker/cli/blob/${version}/scripts/build/.variables
      buildPhase = ''
        export GOCACHE="$TMPDIR/go-cache"

        cd ./go/src/${goPackagePath}
        # Mimic AUTO_GOPATH
        mkdir -p .gopath/src/github.com/docker/
        ln -sf $PWD .gopath/src/github.com/docker/cli
        export GOPATH="$PWD/.gopath:$GOPATH"
        export GITCOMMIT="${rev}"
        export VERSION="${version}"
        export BUILDTIME="1970-01-01T00:00:00Z"
        source ./scripts/build/.variables
        export CGO_ENABLED=1
        go build -tags pkcs11 --ldflags "$LDFLAGS" github.com/docker/cli/cmd/docker
        cd -
      '';

      outputs = [ "out" "man" ];

      installPhase = ''
        cd ./go/src/${goPackagePath}
        install -Dm755 ./docker $out/libexec/docker/docker

        makeWrapper $out/libexec/docker/docker $out/bin/docker \
          --prefix PATH : "$out/libexec/docker:$extraPath"
      '' + optionalString (!clientOnly) ''
        # symlink docker daemon to docker cli derivation
        ln -s ${moby}/bin/dockerd $out/bin/dockerd
        ln -s ${moby}/bin/dockerd-rootless $out/bin/dockerd-rootless

        # systemd
        mkdir -p $out/etc/systemd/system
        ln -s ${moby}/etc/systemd/system/docker.service $out/etc/systemd/system/docker.service
        ln -s ${moby}/etc/systemd/system/docker.socket $out/etc/systemd/system/docker.socket
      '' + ''
        # completion (cli)
        installShellCompletion --bash ./contrib/completion/bash/docker
        installShellCompletion --fish ./contrib/completion/fish/docker.fish
        installShellCompletion --zsh  ./contrib/completion/zsh/_docker
      '' + lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''
        # Generate man pages from cobra commands
        echo "Generate man pages from cobra"
        mkdir -p ./man/man1
        go build -o ./gen-manpages github.com/docker/cli/man
        ./gen-manpages --root . --target ./man/man1
      '' + ''
        # Generate legacy pages from markdown
        echo "Generate legacy manpages"
        ./man/md2man-all.sh -q

        installManPage man/*/*.[1-9]
      '';

      passthru.tests =
        lib.optionals (!clientOnly) { inherit (nixosTests) docker; };

      meta = {
        homepage = "https://www.docker.com/";
        description =
          "An open source project to pack, ship and run any application as a lightweight container";
        license = licenses.asl20;
        maintainers = with maintainers; [
          offline
          tailhook
          vdemeester
          periklis
          mikroskeem
          maxeaubrey
        ];
        platforms = with platforms; linux ++ darwin;
      };

      # Exposed for tarsum build on non-linux systems (build-support/docker/default.nix)
      inherit moby-src;
    });

  # Get revisions from
  # https://github.com/moby/moby/tree/${version}/hack/dockerfile/install/*
  docker_20_10 = callPackage dockerGen rec {
    version = "20.10.14";
    rev = "v${version}";
    sha256 = "sha256-eDwgqFx4io++SMOjhxMxVzqzcOgOnv6Xe/qmmPCvZts=";
    moby-src = fetchFromGitHub {
      owner = "moby";
      repo = "moby";
      rev = "v${version}";
      sha256 = "sha256-I5oxpFLH789I2Sb29OXDaM4fCbQT/KvPq0DYcAVp0aI=";
    };
    runcRev = "v1.0.3";
    runcSha256 = "sha256-Tl/JKbIpao+FCjngPzaVkxse50zo3XQ9Mg/AdkblMcI=";
    containerdRev = "v1.5.11";
    containerdSha256 = "sha256-YzFtv6DIjImSK0SywxhZrEeEmCnHTceAi3pfwnPubKg=";
    tiniRev = "v0.19.0";
    tiniSha256 = "sha256-ZDKu/8yE5G0RYFJdhgmCdN3obJNyRWv6K/Gd17zc1sI=";
  };
}
