resource "aws_ecs_cluster" "main" {
  name = local.name
}

module "ec2" {
  source        = "../base"
  iam_service   = ["ec2", "ecs"]
  name          = local.name
  vpc_id        = var.vpc_id
  subnet_ids    = var.private_subnet_ids
  image_id      = local.image_id
  instance_type = local.instance_type
  user_data = templatefile("${path.module}/user_data.sh", {
    ECS_CLUSTER = aws_ecs_cluster.main.name
  })
  min_size               = local.min_size
  max_size               = local.max_size
  desired_capacity       = local.desired_capacity
  volume_type            = var.volume_type
  volume_size            = var.volume_size
  efs_ids                = var.efs_ids
  efs_security_group_ids = var.efs_security_group_ids
  key_name               = var.key_name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceforEC2Role" {
  role       = module.ec2.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_policy" "AmazonECSServiceRolePolicy" {
  name = "${local.name}-AmazonECSServiceRolePolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECSTaskManagement",
            "Effect": "Allow",
            "Action": [
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:Describe*",
                "ec2:DetachNetworkInterface",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:Describe*",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:RegisterTargets",
                "route53:ChangeResourceRecordSets",
                "route53:CreateHealthCheck",
                "route53:DeleteHealthCheck",
                "route53:Get*",
                "route53:List*",
                "route53:UpdateHealthCheck",
                "servicediscovery:DeregisterInstance",
                "servicediscovery:Get*",
                "servicediscovery:List*",
                "servicediscovery:RegisterInstance",
                "servicediscovery:UpdateInstanceCustomHealthStatus"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECSTagging",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:network-interface/*"
        }
    ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "AmazonECSServiceRolePolicy" {
  role = module.ec2.iam_role_name
  policy_arn = aws_iam_policy.AmazonECSServiceRolePolicy.arn
}

# https://docs.aws.amazon.com/AmazonECS/latest/userguide/task_execution_IAM_role.html
resource "aws_iam_role" "task_execution" {
  name = "${local.name}-AmazonECSTaskExecutionRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

// TODO make more strict `Resourcs: [var.ecr_repo_arns]`
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

