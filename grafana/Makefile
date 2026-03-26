# Makefile (same as before)
PROJECT := grafana
NAMESPACE := devops-tools
ENV ?= prod
CHART := grafana/grafana
RELEASE := grafana

VALUES_FILE := values-$(ENV).yaml

helm_deploy:
	helm upgrade --install $(RELEASE) $(CHART) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		-f values.yaml \
		-f override/$(VALUES_FILE)

grafana_dashboard_deploy:
	docker-compose  \
		-f docker-compose.yaml \
		run \
		-e DEPLOY_CHART=$(CHART) \
		--rm infractl \
		/bin/bash -c "sh /scripts/grafana_deploy_dashboard.sh"
