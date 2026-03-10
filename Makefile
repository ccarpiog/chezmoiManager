SHELL := /bin/bash

.PHONY: release

release:
	TEAM_ID='$(TEAM_ID)' \
	NOTARY_PROFILE='$(NOTARY_PROFILE)' \
	DEVELOPER_ID_APP_CERT='$(DEVELOPER_ID_APP_CERT)' \
	./scripts/release.sh
