#
# ecs assume role policy
#

# trust relationships
data aws_iam_policy_document ecs_assume_role_policy {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource aws_iam_role ecs_service_role {
  name               = "${var.project_name}-ecs-service-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

# attach service-role/AmazonEC2ContainerServiceRole
# Default policy for Amazon ECS service role
resource aws_iam_role_policy_attachment ecs_service_attachment {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

#
# ecs-task assume role policy
#

# trust relationships
data aws_iam_policy_document ecs_task_assume_role_policy {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource aws_iam_role ecs_task_execution_role {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

# attach service-role/AmazonECSTaskExecutionRolePolicy
# Provides access to other AWS service resources that are required to run Amazon ECS tasks
resource aws_iam_role_policy_attachment ecs_task_execution_attachment {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}