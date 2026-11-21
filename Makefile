PERLTIDY ?= perltidy
PERLTIDY_PROFILE := .perltidyrc
PERL_SCRIPTS := pve-overlay image/prepare-installed-source.pl image/test-sriov-overlay.pl

.PHONY: tidy tidy-check

tidy: $(PERLTIDY_PROFILE) $(PERL_SCRIPTS)
	$(PERLTIDY) --profile=$(PERLTIDY_PROFILE) $(PERL_SCRIPTS)

tidy-check: $(PERLTIDY_PROFILE) $(PERL_SCRIPTS)
	@set -e; for script in $(PERL_SCRIPTS); do \
		$(PERLTIDY) --profile=$(PERLTIDY_PROFILE) --assert-tidy --nobackup-and-modify-in-place \
			--standard-output "$$script" > /dev/null; \
	done
