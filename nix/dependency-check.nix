# Keep version checks independent of the full project environment.
pkgs: metadata: {
  interpreter = pkgs.python315;
  python = "${pkgs.python315}/bin/python3";
  inherit metadata;
}
