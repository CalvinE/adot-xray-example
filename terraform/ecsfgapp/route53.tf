resource "aws_route53_record" "mathservice" {
  for_each = var.listener_rule_host_values
  zone_id  = var.route53_zone_id
  name     = each.key
  type     = "A"

  alias {
    name                   = var.alb_domain_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

