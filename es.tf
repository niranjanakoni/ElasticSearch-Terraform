# Define AWS provider configuration
provider "aws" {
  region = "ap-south-1"
  access_key = "string"
  secret_key = "string"
}

# Create Security Group
resource "aws_security_group" "elasticsearch_sg" {
  name        = "elasticsearch_sg"
  description = "Allow elasticsearch inbound traffic"

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow SSH traffic from any source
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP traffic from any source
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 }

 # Allow traffic from any source
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 }
}

# Create an instance with user data which installs ElasticSearch
resource "aws_instance" "elasticsearch" {
  ami = "ami-0f8ca728008ff5af4"                                             # Ubuntu
  instance_type = "t2.micro"
  key_name = "web"                                                          # Existing key pair
  vpc_security_group_ids = [aws_security_group.elasticsearch_sg.id]
  user_data = <<EOF
            #!/bin/bash
              sudo apt-get update
              sudo apt-get install apt-transport-https
              wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
              sudo apt-get install -y openjdk-8-jre-headless elasticsearch
              sudo sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/g' /etc/elasticsearch/elasticsearch.yml
              sudo sed -i 's/#http.port: 9200/http.port: 9200/g' /etc/elasticsearch/elasticsearch.yml
              sudo systemctl enable elasticsearch.service
              sudo systemctl start elasticsearch.service
              EOF

  tags = {
    "Name" = "elasticsearch"
  }
}

# Create an IAM policy for Elasticsearch access
# Create an IAM policy for Elasticsearch access
resource "aws_iam_policy" "elasticsearch" {
  name = "elasticsearch-access"

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "es:ESHttpGet",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "es:ESHttpDelete"
        ],
        "Resource": "arn:aws:es:ap-south-1:<account-id>:domain/elasticsearch/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "es:DescribeElasticsearchDomains",
          "es:ListDomainNames",
          "es:ESHttpHead"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF
}

# Create an IAM user for Elasticsearch access
resource "aws_iam_user" "elasticsearch" {
  name = "elasticsearch-user"
}

# Attach the Elasticsearch policy to the IAM user
resource "aws_iam_user_policy_attachment" "elasticsearch" {
  user       = aws_iam_user.elasticsearch.name
  policy_arn = aws_iam_policy.elasticsearch.arn
}

# Output the Elasticsearch endpoint URL
output "elasticsearch_endpoint" {
  value = aws_elasticsearch_domain.elasticsearch.endpoint
}