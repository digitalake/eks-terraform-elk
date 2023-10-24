# <h1 align="center">eks-terraform-elk</a>

This repo contains:

- Terraform code for deploying `EKS`
- Helm values for `ELK stack` + `Filebeat` for deploying loging solution to the cluster

### Terraform, EKS
`
In thise particular task, the EKS managed node group is used. For using `gp2` StorageClass volumes, I needed to add `ebs-csi-driver`, so my addons are:

- Kube-proxy
- CoreDNS
- VPC-CNI
- EBS-CSI

Defined by the variable:
```
variable "eks_cluster_addons" {
  type        = map(any)
  description = "Define the Kubernetes addons to install"
  default = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}
```

EKS `audit` and `API server` logs will be also exposed for accessing through the `ClodWatch` AWS solution.
 
After running `terraform apply`, fetching `Kubeconfig`:
```
aws eks update-kubeconfig --name $cluster-name --region $region
```
### Kubernetes API server logs with CloudWatch

AWS allows to connect the Kubernetes API server logs as well as the audit logs to the CloudWatch (works only if those types of logs are enabled).

Kube API server log streams in CloudWatch:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/39e81b06-a6d1-4fee-a0d1-21787c18d556)

By filtering logs by `{ ($.verb = "create") }` we can look, for example, on `Logstash` creation event:

```
{
    "kind": "Event",
    "apiVersion": "audit.k8s.io/v1",
    "level": "RequestResponse",
    "auditID": "2dfe8443-77a2-47ff-b05c-fbe90bb332fb",
    "stage": "ResponseComplete",
    "requestURI": "/api/v1/namespaces/default/events",
    "verb": "create",
    "user": {},
    "sourceIPs": [
        "10.0.1.183"
    ],
    "userAgent": "kubelet/v1.28.1 (linux/amd64) kubernetes/5024547",
    "objectRef": {
        "resource": "events",
        "namespace": "default",
        "name": "logstash-logstash-0.1790957e916215d8",
        "apiVersion": "v1"
    },
    "responseStatus": {
        "metadata": {},
        "code": 201
    },
    "requestObject": {
        "kind": "Event",
        "apiVersion": "v1",
        "metadata": {
            "name": "logstash-logstash-0.1790957e916215d8",
            "namespace": "default",
            "creationTimestamp": null
        },
        "involvedObject": {
            "kind": "Pod",
            "namespace": "default",
            "name": "logstash-logstash-0",
            "uid": "afae31f1-6106-432a-97d4-dbd9cdaf6d22",
            "apiVersion": "v1",
            "resourceVersion": "82191",
            "fieldPath": "spec.containers{logstash}"
        },
        "reason": "Pulled",
        "message": "Container image \"docker.elastic.co/logstash/logstash:8.5.1\" already present on machine",
        "source": {
            "component": "kubelet",
            "host": "ip-10-0-1-183.ec2.internal"
        },
        "firstTimestamp": "2023-10-23T00:37:10Z",
        "lastTimestamp": "2023-10-23T00:37:10Z",
        "count": 1,
        "type": "Normal",
        "eventTime": null,
        "reportingComponent": "kubelet",
        "reportingInstance": "ip-10-0-1-183.ec2.internal"
    },
    "responseObject": {
        "kind": "Event",
        "apiVersion": "v1",
        "metadata": {
            "name": "logstash-logstash-0.1790957e916215d8",
            "namespace": "default",
            "uid": "9877c9fe-27f9-498d-9c21-07c3e601842e",
            "resourceVersion": "82200",
            "creationTimestamp": "2023-10-23T00:37:10Z",
            "managedFields": [
                {
                    "manager": "kubelet",
                    "operation": "Update",
                    "apiVersion": "v1",
                    "time": "2023-10-23T00:37:10Z",
                    "fieldsType": "FieldsV1",
                    "fieldsV1": {
                        "f:count": {},
                        "f:firstTimestamp": {},
                        "f:involvedObject": {},
                        "f:lastTimestamp": {},
                        "f:message": {},
                        "f:reason": {},
                        "f:reportingComponent": {},
                        "f:reportingInstance": {},
                        "f:source": {
                            "f:component": {},
                            "f:host": {}
                        },
                        "f:type": {}
                    }
                }
            ]
        },
        "involvedObject": {
            "kind": "Pod",
            "namespace": "default",
            "name": "logstash-logstash-0",
            "uid": "afae31f1-6106-432a-97d4-dbd9cdaf6d22",
            "apiVersion": "v1",
            "resourceVersion": "82191",
            "fieldPath": "spec.containers{logstash}"
        },
        "reason": "Pulled",
        "message": "Container image \"docker.elastic.co/logstash/logstash:8.5.1\" already present on machine",
        "source": {
            "component": "kubelet",
            "host": "ip-10-0-1-183.ec2.internal"
        },
        "firstTimestamp": "2023-10-23T00:37:10Z",
        "lastTimestamp": "2023-10-23T00:37:10Z",
        "count": 1,
        "type": "Normal",
        "eventTime": null,
        "reportingComponent": "kubelet",
        "reportingInstance": "ip-10-0-1-183.ec2.internal"
    },
    "requestReceivedTimestamp": "2023-10-23T00:37:10.356954Z",
    "stageTimestamp": "2023-10-23T00:37:10.361539Z",
    "annotations": {
        "authorization.k8s.io/decision": "allow",
        "authorization.k8s.io/reason": ""
    }
}
```


### ELKF

The main working principle of the `ELK` solution can be described with the diagram:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/d81aeb44-a74c-4a4d-bf5e-9fdd86f4ed70)

So the following `Helmcharts` are used:

- `Filebeat` for scrapping logs
- `Elasticsearch` as a log-engine + log-starage 
- `Kibana` for dashboards
- `Logstash` for log pipeline

### Filebeat

Filebeat is configured to fetch container logs and pushing them to the `Service` Kubernetes resource of the `Logstash` which will be accessible on the `5044` port:

```
filebeatConfig:
    filebeat.yml: |
      filebeat.inputs:
      - type: container
        paths:
          - /var/log/containers/*.log
        processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
      output.logstash:
        hosts: ["logstash-logstash:5044"]
```

### Logstash

In `Logstash` values, the service needs to be enabled:

```
service:
   type: ClusterIP
   ports:
    - name: beats
      port: 5044
      protocol: TCP
      targetPort: 5044
```

For beeing able to push logs to the `Elasticsearch`, `Logstash` needs Secret mount with Certificate Authority and Secret for Credentials:

```
secretMounts:
- name: certificates
  secretName: elasticsearch-master-certs
  path: /etc/logstash/certificates
...
envFrom: 
- secretRef:
    name: elasticsearch-master-credentials
```

`elasticsearch-master-certs` Secret as well as `elasticsearch-master-credentials` will be generated by the Elasticsearch.

So now they can be used to configure the pipeline:

```
logstashPipeline:
  logstash.conf: |
    input {
      beats {
        port => 5044
      }
    }
    output { 
      elasticsearch {
        hosts => [ "https://elasticsearch-master:9200" ]
        user => "${username}"
        password => "${password}"
        ssl => true
        cacert => '/etc/logstash/certificates/ca.crt'
      } 
    }
```

### Elasticsearch 

`Elasticsearch` is exposed with the `Service` on `9200` port:

```
protocol: https
httpPort: 9200
```

Also it requires the storage:
```
volumeClaimTemplate:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 30Gi
```

Enabling certificate and credential secrets creation:
```
createCert: true
...
secret:
  enabled: true
```

### Kibana

`Kibana` requires certificate and credentials configuration:

```
elasticsearchHosts: "https://elasticsearch-master:9200"
elasticsearchCertificateSecret: elasticsearch-master-certs
elasticsearchCertificateAuthoritiesFile: ca.crt
elasticsearchCredentialSecret: elasticsearch-master-credentials
```

### Deploying ELK+Filebeat + Results

Deploying ELKF Charts via `Helm`:
```
helm install $release-name elastic/$chart -f $path-to-values-file
```

`Pods` are deployed:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/e9c7e11e-abd1-4eaf-b6bc-99cf30c5ff5d)

`Secrets` created:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/38a8d5ab-a688-422d-9435-36cc1f8ddef5)

`Filebeat` mounts:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/c1e0ed75-48ae-4920-97cd-bfe56823f437)

`Logstash` detected `Elasticsearch` url:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/74092715-599b-4684-a9e8-7650e1963e32)

`Logstash` is ready for `Filebeat` beats:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/b59b46e4-bc91-4dc1-9aa3-7cbdb544c96e)

`Elasticsearch` is ready:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/dc928c3c-8289-423c-a282-8fe985751a9b)

`Kibana` is ready:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/d99998c6-772c-4825-8f1a-99760bee18b3)

Application logs via `Kibana`:

![image](https://github.com/digitalake/eks-terraform-elk/assets/109740456/59c1f6e4-afc6-47b2-8c67-493409accfbb)




