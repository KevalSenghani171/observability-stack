apiVersion: 1
datasources: 
  - name: prometheus-main
    type: prometheus
    url: http://prometheus-server.devops-tools.svc.cluster.local:9090
    uid: asdcap220gzkb
    httpMode: 'POST'
    editable: false
    default: true
    orgId: 1
  - name: loki-main
    type: loki
    url: http://loki.devops-tools.svc.cluster.local:3100
    uid: casdgdf4kpvkf
    httpMode: 'POST'
    editable: false
    orgId: 1
  - name: pyroscope-main
    type: grafana-pyroscope-datasource
    url: http://pyroscope.devops-tools.svc.cluster.local:4040
    uid: afifnbjlasdcad
    httpMode: 'POST'
    editable: false
    orgId: 1
  - name: jaeger-main
    type: jaeger
    url: http://jaeger.observability.svc.cluster.local:16686
    uid: dfhgk66yawas
    httpMode: 'POST'
    editable: false
    orgId: 1
