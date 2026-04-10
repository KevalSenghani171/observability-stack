apiVersion: 1
datasources: 
  - name: prometheus
    type: prometheus
    url: http://prometheus-server.devops-tools.svc.cluster.local:9090
    uid: ffgyyyp220gzkb
    httpMode: 'POST'
    editable: false
    default: true
    orgId: 1
  - name: loki
    type: loki
    url: http://loki.devops-tools.svc.cluster.local:3100
    uid: dfifngdf4kpvkf
    httpMode: 'POST'
    editable: false
    orgId: 1
  - name: pyroscope
    type: grafana-pyroscope-datasource
    url: http://pyroscope.devops-tools.svc.cluster.local:4040
    uid: afifnbjlqxmv4d
    httpMode: 'POST'
    editable: false
    orgId: 1
  - name: jaeger
    type: jaeger
    url: http://jaeger.observability.svc.cluster.local:16686
    uid: dfhgk66yw5nuoc
    httpMode: 'POST'
    editable: false
    orgId: 1
