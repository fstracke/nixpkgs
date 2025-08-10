{
  lib,
  stdenv,
  buildFHSEnvBubblewrap,
  fetchurl,
  dpkg,
  pkgs,
  makeWrapper,
  wrapGAppsHook,
  extraPkgs ? pkgs: [],
}:
stdenv.mkDerivation rec {
  pname = "amsel-suite";
  version = "1.4.2";

  src = fetchurl {
    url = "https://github.com/OllamTechnologies/launcher-releases/releases/download/v${version}/amsel-suite_${version}_amd64.deb";
    hash = "sha256:d723659cdca890ee5ca15325bf3fd8d0feb346367541e1ca154704699daddc26";
  };

  nativeBuildInputs = [dpkg wrapGAppsHook makeWrapper];

  unpackCmd = ''dpkg -x $curSrc src || true'';

  fhsEnv = buildFHSEnvBubblewrap {
    pname = "${pname}-fhs-env";
    inherit version;

    targetPkgs = pkgs: let
      pkexecShim = pkgs.writeShellScriptBin "pkexec" ''
        #!/bin/sh
        echo "[amsel-fhsenv] sudo shim: running without privileges"
        # Führt den Befehl ohne Rechte aus (nur innerhalb des FHS-Env)
        shift;
        exec "$@";
      '';
    in
      with pkgs;
        [
          pkexecShim
          uutils-coreutils-noprefix
          glib
          gsettings-desktop-schemas
          hicolor-icon-theme
          nss
          nspr
          dbus
          dbus.lib
          at-spi2-atk
          cups.lib
          gtk3
          pango
          cairo
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXfixes
          xorg.libXrandr
          libgbm
          xorg.libxcb
          libxkbcommon
          alsa-lib
          ffmpeg
          libdrm
          xorg.libXext
          libGL
          udev
          expat
        ]
        ++ extraPkgs pkgs;

    # Wrapper, der persistente Ordner anlegt
    # erzeuge die Host-Ordner (wird beim Start des wrappers ausgeführt)
    extraPreBwrapCmds = ''
      mkdir -p "$HOME/.local/share/amsel-suite/opt"
    '';

    # bwrap-Argumente: binden der Host-Pfade in das FHS-Environment
    # $HOME bleibt eine Laufzeit-Variable (wird vom erzeugten Startskript expandiert)
    extraBwrapArgs = [
      "--bind-try $HOME/.local/share/amsel-suite/opt /opt"
      "--bind-try $HOME $HOME"
      "--bind-try /tmp/testing /tmp/testing"
    ];
    runScript = "";
    profile = ''
      export NIXOS_OZONE_WL=1
    '';
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    mkdir -p $out/opt
    cp -r usr/ $out
    makeWrapper ${fhsEnv}/bin/${pname}-fhs-env $out/usr/lib/amsel-suite/amsel-suite \
      --add-flags "$out/usr/lib/amsel-suite/Amsel\ Suite \''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
      "''${gappsWrapperArgs[@]}"

    rm $out/usr/bin/amsel-suite
    ln -s $out/usr/lib/amsel-suite/amsel-suite $out/usr/bin/amsel-suite

    runHook postInstall
  '';

  meta = with lib; {
    description = "Launcher for the Amsel Suite by Ollam Technologies";
    homepage = "https://www.amsel-suite.com/";
    license = licenses.unfree;
    platforms = ["x86_64-linux"];
    maintainers = with maintainers; [fstracke];
    sourceProvenance = with sourceTypes; [binaryNativeCode];
  };
}
