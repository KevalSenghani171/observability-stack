NAMESPACE=devops-tools

dashboard_deploy:
	kubectl create configmap grafana-dashboard \
		--from-file=dashboards \
		-n $(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -

datasource_deploy:
	kubectl apply -f datasources/

alert_deploy:
	kubectl apply -f alerting/

deploy:
	infractl apply -f infractl.yaml
