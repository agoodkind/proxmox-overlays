PERLTIDY ?= perltidy
PERLTIDY_PROFILE := .perltidyrc
PERL_SCRIPTS := pve-overlay image/prepare-installed-source.pl image/test-sriov-overlay.pl image/test-sriov-restore.pl test/patch-series.t

.PHONY: tidy tidy-check test

tidy: $(PERLTIDY_PROFILE) $(PERL_SCRIPTS)
	$(PERLTIDY) --profile=$(PERLTIDY_PROFILE) $(PERL_SCRIPTS)

tidy-check: $(PERLTIDY_PROFILE) $(PERL_SCRIPTS)
	@set -e; for script in $(PERL_SCRIPTS); do \
		$(PERLTIDY) --profile=$(PERLTIDY_PROFILE) --assert-tidy --nobackup-and-modify-in-place \
			--standard-output "$$script" > /dev/null; \
	done

test:
	prove test/patch-series.t
