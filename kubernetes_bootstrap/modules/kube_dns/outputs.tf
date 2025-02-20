output "chart" {
  value = module.metadata.chart
}

output "prometheus_jobs" {
  value = local.prometheus_jobs
}