provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_db_instance" "demo2_rds" {
  name = "demo2_rds"
  depends_on              = ["aws_security_group.demo2_rds_secgroup"]
  identifier              = "${var.rds_identifier}"
  allocated_storage       = "${var.db_storage_size}"
  storage_type            = "gp2"
  instance_class          = "${var.db_instance_class}"
  engine                  = "${var.db_engine}"
  engine_version          = "${var.db_engine_version}"
  port                    = "${var.db_port}"
  backup_retention_period = "0"
  name                    = "${var.db_name}"
  username                = "${var.db_user}"
  password                = "${var.db_pass}"
  publicly_accessible     = "false"
  vpc_security_group_ids  = ["${aws_security_group.demo2_rds_secgroup.id}"]
  db_subnet_group_name    = "${aws_db_subnet_group.demo2_db_subnet_group.id}"

  provisioner "local-exec" {
    command = "../../job-dsl/populate-database.sh"
  }
}

resource "aws_elb" "demo2_elb" {
  name                = "${var.elb_name}"
# depends_on          = ["aws_security_group.demo2_elb_secgroup"]
# Only one of SubnetIds or AvailabilityZones parameter may be specified
# availability_zones  = ["${split(",", var.availability_zones)}"] # The same availability zone as autoscaling group instances have
  subnets             = ["${aws_subnet.demo2_subnet1.id}", "${aws_subnet.demo2_subnet2.id}", "${aws_subnet.demo2_subnet3.id}"] # The same subnet as autoscaling group instances have
# subnets             = ["${aws_subnet.demo2_subnet1.id}"]
  security_groups     = ["${aws_security_group.demo2_elb_secgroup.id}"]
  listener {
    instance_port     = "${var.webapp_port}"
    instance_protocol = "http"
    lb_port           = "${var.webapp_port}"
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 15
    target              = "HTTP:${var.webapp_port}/login"
    interval            = 20
  }
# instances                   = ["${aws_instance.demo2_tomcat.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 600
}

resource "aws_lb_cookie_stickiness_policy" "default" {
  name                     = "lb-cookie-stickiness-policy"
# depends_on               = ["aws_elb.demo2_elb"]
  load_balancer            = "${aws_elb.demo2_elb.id}"
  lb_port                  = "${var.webapp_port}"
  cookie_expiration_period = 600
}

resource "aws_launch_configuration" "demo2_launch_configuration" {
  name                  = "demo2_launch_configuration"
  depends_on            = ["aws_security_group.demo2_webapp_secgroup"]
  image_id              = "${var.ec2_ami}"
  instance_type         = "${var.ec2_instance_type}"
  security_groups       = ["${aws_security_group.demo2_webapp_secgroup.id}"]
  user_data             = "${file("../../job-dsl/userdata.sh")}"
  key_name              = "${var.ssh_key_name}"
  iam_instance_profile  = "${var.iam_profile}" # IAM role for ec2 instances in launch configuration. Role gives read only permissions to S3, RDS, SSM
# Must provide at least one classic link security group if a classic link VPC is provided.
# vpc_classic_link_id   = "${var.default_vpc_id}}"
  enable_monitoring     = "false"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "demo2_autoscalegroup" {
  name                 = "${var.autoscalegroup_name}"
# availability_zones should be used only if no vpc_zone_identifier parameter is specified
# availability_zones   = ["${var.availability_zone1}", "${var.availability_zone2}", "${var.availability_zone3}"]

# Added dependency on aws_db_instance.demo2_rds to wait for RDS database creation and population before creating
# autoscaling group with ec2 instances, because their userdata scripts tries to retrieve data from RDS database
# depends_on           = ["aws_db_instance.demo2_rds", "aws_launch_configuration.demo2_launch_configuration", "aws_subnet.demo2_subnet"]
# depends_on           = ["aws_launch_configuration.demo2_launch_configuration"]
  max_size             = "${var.max_servers_in_autoscaling_group}"
  min_size             = "${var.min_servers_in_autoscaling_group}"
  desired_capacity     = "${var.desired_servers_in_autoscaling_group}"
  launch_configuration = "${aws_launch_configuration.demo2_launch_configuration.name}"
  health_check_type    = "ELB"
# Alternative to attaching load balancers here is using resource "aws_autoscaling_attachment"
  load_balancers       = ["${aws_elb.demo2_elb.name}"]
# vpc_zone_identifier should be used only if no availability_zones parameter is specified.
  vpc_zone_identifier  = ["${aws_subnet.demo2_subnet1.id}", "${aws_subnet.demo2_subnet2.id}", "${aws_subnet.demo2_subnet3.id}"]
  termination_policies = ["OldestInstance"]

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "webapp"
    propagate_at_launch = "true"
  }
}

# Attach classic load balancer to autoscaling group here can be used instead of using parameter load_balancers at resource "aws_autoscaling_group"
# resource "aws_autoscaling_attachment" "asg_attachment_bar" {
#   depends_on             = ["aws_autoscaling_group.demo2_autoscalegroup"]
#   autoscaling_group_name = "${aws_autoscaling_group.demo2_autoscalegroup.id}"
#   elb                    = "${aws_elb.demo2_elb.id}"
# }
