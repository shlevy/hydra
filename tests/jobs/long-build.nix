with import ./config.nix;
{
  long_build =
    mkDerivation {
      name = "long-build";
      builder = ./long-build-builder.sh;
    };
}
