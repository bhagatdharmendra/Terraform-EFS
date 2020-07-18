
provider "aws" {
	 region= "ap-south-1"
	 profile = "gaurav"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_http"
  }
}
resource "aws_instance" "web" {
	ami = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	availability_zone = "ap-south-1a"
	security_groups = ["${aws_security_group.allow_http.name}"]
	key_name = "deployer-key"
	tags = {
		Name = "TerraForm Server"
	}

provisioner "remote-exec" {
connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/gaura/Task-2/deployer-key.pem")
    host     = aws_instance.web.public_ip
  }
    inline = [
      "sudo yum install httpd git amazon-efs-utils nfs-utils php -y ", 
      "sudo systemctl restart httpd", 
      "sudo systemctl enable httpd",
      ]
}
}
resource "aws_efs_file_system" "foo" {
  creation_token = "my-product"
    tags = {
    Name = "EFS_For_Terraform"
    
  }
}


resource "aws_efs_mount_target" "alpha" {
  depends_on =  [ aws_efs_file_system.foo,]
  file_system_id = aws_efs_file_system.foo.id
  subnet_id      = aws_instance.web.subnet_id
  security_groups = ["${aws_security_group.allow_http.id}"]

}

resource "null_resource" "nullremote3"  {
  depends_on = [aws_efs_mount_target.alpha,]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/gaura/Task-2/deployer-key.pem") 
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
  inline = [
      "sudo mount -t nfs4 ${aws_efs_mount_target.alpha.ip_address}:/ /var/www/html/", 
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Gaurav1829/Terraform.git  /var/www/html/"
  ]
}
}

#Creating S3 Bucket

resource "aws_s3_bucket" "bucket" {
  bucket = "terrabucket2021"
  acl = "private"
  region = "ap-south-1"
}

resource "aws_s3_bucket_object" "object" {
	bucket = "terrabucket2021"
	key = "vimalsir.jpg"
	source = "vimalsir.jpg"
}

locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "OAI"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
enabled             = true
  is_ipv6_enabled     = true
default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.bucket.arn}"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

