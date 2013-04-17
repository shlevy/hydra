API_TESTS = \
  api/login-test.pl \
  api/logout-test.pl

AM_TESTS_ENVIRONMENT = \
  export BZR_HOME="$(abs_builddir)/data"		\
  HYDRA_DBI="dbi:SQLite:db.sqlite"			\
  HYDRA_DATA="$(abs_builddir)/data"			\
  HYDRA_HOME="$(top_srcdir)/src"			\
  NIX_REMOTE=						\
  NIX_CONF_DIR="$(abs_builddir)/nix/etc/nix"		\
  NIX_STATE_DIR="$(abs_builddir)/nix/var/nix"		\
  NIX_MANIFESTS_DIR="$(abs_builddir)/nix/var/nix/manifests"	\
  NIX_STORE_DIR="$(abs_builddir)/nix/store"			\
  NIX_LOG_DIR="$(abs_builddir)/nix/var/log/nix"		\
  NIX_BUILD_HOOK=					\
  PERL5LIB="$(srcdir):$(top_srcdir)/src/lib:$$PERL5LIB"	\
  PATH=$(abs_top_srcdir)/src/script:$(abs_top_srcdir)/src/c:$$PATH \
  API_TESTS="$(API_TESTS)";

LOG_COMPILER = perl

AM_LOG_FLAGS = -w

EXTRA_DIST = \
  $(wildcard *.pm) \
  $(wildcard jobs/*.nix) \
  $(wildcard jobs/*.sh) \
  $(API_TESTS) \
  fixture-setup.sql \
  $(TESTS)

TESTS = \
  query-all-tables.pl \
  evaluation-tests.pl \
  api.pl

clean:
	chmod -R a+w nix || true
	rm -rf db.sqlite data nix git-repo hg-repo svn-repo svn-checkout svn-checkout-repo bzr-repo bzr-checkout-repo
	rm -f .*-state

check_SCRIPTS = db.sqlite repos

db.sqlite: $(top_srcdir)/src/sql/hydra-sqlite.sql $(srcdir)/fixture-setup.sql
	$(AM_TESTS_ENVIRONMENT) $(LOG_COMPILER) $(AM_LOG_FLAGS) $(top_srcdir)/src/script/hydra-init
	sqlite3 $@ < $(srcdir)/fixture-setup.sql

repos: dirs

dirs:
	mkdir -p data
	touch data/hydra.conf
	mkdir -p nix
	mkdir -p nix/etc/nix
	touch nix/etc/nix/nix.conf
	mkdir -p nix/store
	mkdir -p nix/var
