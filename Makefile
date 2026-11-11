DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*) bin
EXCLUSIONS := .git .gitignore .gvimrc .vsvimrc .ideavimrc .tmux.remote.conf
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

.PHONY: deploy clean test-shell

test-shell:
	@set -e; for test_file in "$(DOTPATH)"/tests/shell/*_test.sh; do \
		bash "$$test_file"; \
	done

deploy:
	@DOTPATH=$(DOTPATH) bash $(DOTPATH)/etc/init/deploy.sh

clean:
	@echo "Remove dotfiles in your home directory..."
	@DOTPATH=$(DOTPATH) bash $(DOTPATH)/etc/init/clean.sh
