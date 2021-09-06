# f-poc

## Setup

* terraform 0.14.11
* python pip awscli pre-commit

1. Create new AWS Account setup root user with MFA.
2. Create another user with `AdministratorAccess` role attached and also setup MFA.
3. git clone this repository
5. Install pre-commit hooks `pre-commit install`

## Terraform

### tf-state

This will deploys a S3 bucket and dynamodb table for terraform state storage and locking.

1. change directory to `terraform/tf-state`
2. `terraform init`
3. `terraform apply`
4. push terraform state to s3
   1. un-comment terraform s3 backend
   2. `terraform init`
   3. `terraform apply`

#### delete tf-state

1. `terraform state pull > terraform.tfstate`
2. comment terraform s3 backend
3. `terraform init`
4. `terraform destroy -target <terraform-resource-name>` all resources except s3 bucket.
5. empty s3 bucket and manaully delete.

### environment

This deploys ECS/Fargate (nginx container), AWS Elasticsearch Service and a EC2 instance used as a bastion (only accessible via AWS Systems Manager Session Manager).

https://aws.amazon.com/premiumsupport/knowledge-center/systems-manager-ssh-vpc-resources/

1. change directory to `terraform/environment`
2. `terraform init`
3. `terraform apply`

## Security Recommendations

If someone is wanting to limit egress of internet access I would switch to VPC Endpoint(s). This can cost slightly more than a NAT gateway and it also has a lot more configuration involved but it gives the most control and is a very secure approach.

### ECS

* Switch to an aws ecr repository (guards against public infrastructure downtimes)
* Use VPC endpoints for ecr access (no NAT gateway is required)
* Switch to containers using TLS/SSL instead of plain text. Once this is done update load balancer to use HTTPS.
* Move to an internal load balancer in the private subnet and only allow access over the private subnet. This also requires something like AWS Client VPN.

### Elastic Search

* switch to cognito/SAML authentication instead of a master user. https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/saml.html
* Once this is done the master user/password can be removed.
* find another option to automate the lambda to deliver logs from cloudwatchLogs to elasticsearch.
* see if there is a way to automate other configuration details of managing elasticsearch like dashboards.

### EC2

* I would remove this instance and setup AWS Client VPN and setup Elastic Search and Kibana to work over AWS Client VPN only.

### Misc

* tf-state should have more limited IAM policies for s3/dyanmodb.
* Name/tag all things to allow for better tracking/understanding resources.
