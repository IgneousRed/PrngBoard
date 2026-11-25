{ pkgs, python }:

pkgs.git.override {
  python3 = python;
}
