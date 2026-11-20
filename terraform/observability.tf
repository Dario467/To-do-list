# ---------- SNS ----------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- Alarma 1: metrica nativa (RDS CPUUtilization) ----------
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-cpu-alta"
  alarm_description   = "CPU de RDS sostenida por encima de 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.db.identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------- Alarma 2: errores de RDS (propia) ----------
resource "aws_cloudwatch_metric_alarm" "rds_errors" {
  alarm_name          = "${var.project_name}-rds-errores"
  alarm_description   = "La app reporta errores al leer o escribir en RDS"
  namespace           = "TodoApp"
  metric_name         = "RDSErrors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------- Alarma 3: tareas creadas (propia) ----------
resource "aws_cloudwatch_metric_alarm" "tasks_created" {
  alarm_name          = "${var.project_name}-pico-de-tareas"
  alarm_description   = "Pico anormal de tareas creadas en 5 minutos"
  namespace           = "TodoApp"
  metric_name         = "TasksCreated"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------- Dashboard ----------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = file("${path.module}/../alerting/cloudwatch-dashboard.json")
}
