DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*) bin
EXCLUSIONS := .git .gitignore .gvimrc .vsvimrc .ideavimrc .tmux.remote.conf
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

deploy:
	@DOTPATH=$(DOTPATH) bash $(DOTPATH)/etc/init/deploy.sh

clean:
	@echo "Remove dotfiles in your home directory..."
	@DOTPATH=$(DOTPATH) bash $(DOTPATH)/etc/init/clean.sh
