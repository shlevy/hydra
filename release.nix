{ hydraSrc ? { outPath = ./.; revCount = 1234; gitTag = "abcdef"; }
, officialRelease ? false
}:

let
  config = {
    perlPackageOverrides = p: {
      DBIxClass = with p.perlPackages; buildPerlPackage {
        name = "DBIx-Class-0.08249_2";
        src = fetchurl {
          url = http://cpan.metacpan.org/authors/id/R/RI/RIBASUSHI/DBIx-Class-0.08249_02.tar.gz;
          sha256 = "1xs65d3zy5dn90sy440rnrdph6wy75h0d3w4hvjxgb65zrm45068";
        };
        buildInputs = [ DBDSQLite PackageStash TestException TestWarn TestDeep ];
        propagatedBuildInputs = [ ClassAccessorGrouped ClassC3Componentised ClassInspector ClassMethodModifiers ConfigAny ContextPreserve DataCompare DataDumperConcise DataPage DBI DevelGlobalDestruction HashMerge ModuleFind Moo MROCompat namespaceclean PathClass ScopeGuard SQLAbstract strictures SubName TryTiny ];
        meta = {
          homepage = http://www.dbix-class.org/;
          description = "Extensible and flexible object <-> relational mapper";
          license = "perl";
        };
      };
    };

    packageOverrides = p: {
      sqlite = p.lib.overrideDerivation p.sqlite (attrs: {
        name = "sqlite-3.7.14.1";
         src = p.fetchurl {
           url = http://www.sqlite.org/sqlite-autoconf-3071401.tar.gz;
           sha1 = "c464e0e3efe98227c6546b9b1e786b51b8b642fc";
         };
      });
    };
  };
in rec {

  tarball =
    with import <nixpkgs> { inherit config; };

    releaseTools.makeSourceTarball {
      name = "hydra-tarball";
      src = hydraSrc;
      inherit officialRelease;
      version = builtins.readFile ./version;

      buildInputs =
        [ perl libxslt dblatex tetex nukeReferences pkgconfig boehmgc git openssl ];

      versionSuffix = if officialRelease then "" else "pre${toString hydraSrc.revCount}-${hydraSrc.gitTag}";

      preConfigure = ''
        # TeX needs a writable font cache.
        export VARTEXFONTS=$TMPDIR/texfonts
      '';

      configureFlags =
        [ "--with-nix=${nix}"
          "--with-docbook-xsl=${docbook_xsl}/xml/xsl/docbook"
        ];

      postDist = ''
        make -C doc/manual install prefix="$out"
        nuke-refs "$out/share/doc/hydra/manual.pdf"

        echo "doc manual $out/share/doc/hydra manual.html" >> \
          "$out/nix-support/hydra-build-products"
        echo "doc-pdf manual $out/share/doc/hydra/manual.pdf" >> \
          "$out/nix-support/hydra-build-products"
      '';
    };


  build =
    { system ? "x86_64-linux" }:

    let pkgs = import <nixpkgs> {inherit system config;}; in

    with pkgs;

    let nix = nixUnstable; in

    releaseTools.nixBuild {
      name = "hydra";
      src = tarball;
      configureFlags = "--with-nix=${nix}";

      buildInputs =
        [ perl makeWrapper libtool nix unzip nukeReferences pkgconfig boehmgc sqlite
          git gitAndTools.topGit mercurial subversion bazaar openssl bzip2
        ] ++ (import ./deps.nix) { inherit pkgs; };

      hydraPath = lib.makeSearchPath "bin" (
        [ libxslt sqlite subversion openssh nix coreutils findutils
          gzip bzip2 lzma gnutar unzip git gitAndTools.topGit mercurial gnused graphviz bazaar
        ] ++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ] );

      preConfigure = "patchShebangs .";

      postInstall = ''
        mkdir -p $out/nix-support
        nuke-refs $out/share/doc/hydra/manual/manual.pdf

        for i in $out/bin/*; do
            wrapProgram $i \
                --prefix PERL5LIB ':' $out/libexec/hydra/lib:$PERL5LIB \
                --prefix PATH ':' $out/bin:$hydraPath \
                --set HYDRA_RELEASE ${tarball.version} \
                --set HYDRA_HOME $out/libexec/hydra \
                --set NIX_RELEASE ${nix.name}
        done
      ''; # */

      LOGNAME = "foo";

      enableParallelBuilding = true;

      meta.description = "Build of Hydra on ${system}";
    };


  tests =
    { nixos ? ../nixos, system ? "x86_64-linux" }:

    let hydra = build { inherit system; }; in

    with import <nixos/lib/testing.nix> { inherit system; };

    {

      install = simpleTest {

        machine =
          { config, pkgs, ... }:
          { services.postgresql.enable = true;
            services.postgresql.package = pkgs.postgresql92;
            environment.systemPackages = [ hydra ];
          };

        testScript =
          ''
            $machine->waitForJob("postgresql");

            # Initialise the database and the state.
            $machine->mustSucceed
                ( "createdb -O root hydra",
                , "psql hydra -f ${hydra}/libexec/hydra/sql/hydra-postgresql.sql"
                , "mkdir /var/lib/hydra"
                );

            # Start the web interface.
            $machine->mustSucceed("HYDRA_DATA=/var/lib/hydra HYDRA_DBI='dbi:Pg:dbname=hydra;user=hydra;' hydra-server >&2 &");
            $machine->waitForOpenPort("3000");
          '';

      };

    };


}
