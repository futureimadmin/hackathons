# VPN Gateway for on-premises connectivity

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  count  = var.enable_vpn ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpn-gateway"
    Environment = var.environment
  }
}

# Customer Gateway (represents your on-premises router)
resource "aws_customer_gateway" "main" {
  count      = var.enable_vpn && var.customer_gateway_ip != "" ? 1 : 0
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name        = "${var.project_name}-${var.environment}-customer-gateway"
    Environment = var.environment
  }
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "main" {
  count               = var.enable_vpn && var.customer_gateway_ip != "" ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.main[0].id
  customer_gateway_id = aws_customer_gateway.main[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpn-connection"
    Environment = var.environment
  }
}

# Static route for on-premises network
resource "aws_vpn_connection_route" "onprem" {
  count                  = var.enable_vpn && var.customer_gateway_ip != "" ? 1 : 0
  destination_cidr_block = var.onprem_cidr_block
  vpn_connection_id      = aws_vpn_connection.main[0].id
}

# Enable VPN route propagation on private route tables
resource "aws_vpn_gateway_route_propagation" "private" {
  count          = var.enable_vpn ? length(aws_route_table.private) : 0
  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = aws_route_table.private[count.index].id
}

# Add static route to on-premises network in private route tables
resource "aws_route" "onprem_to_private" {
  count                  = var.enable_vpn && !var.use_route_propagation ? length(aws_route_table.private) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = var.onprem_cidr_block
  gateway_id             = aws_vpn_gateway.main[0].id
}
